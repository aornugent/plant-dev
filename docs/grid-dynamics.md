# The grid's cost and error: a debugging record

Which interactions of the system, the solver and the controller block a
predictable error, cost efficiency or inflate runtime, debugged from the runs
on disk with a few cheap probes. Long drought, seed 31, 108 uniform nodes,
Cash–Karp at `3e-5`, unless stated.

Each symptom below is reproduced first, then traced to the component that
produces it. A root cause is claimed only where a test of one variable confirmed
it. Refuted hypotheses are kept.

**What a gradient run pays.** A run with every gradient of both roles is about
seven forwards: the forward, the stand's sweep (2.6, `perf-adjoint.md`), the
invader's walk (0.8, §3) and its sweep (2.6). The walk and the sweeps pay each
accepted step's members again, its rows. Rejected attempts and the forward's
cost per member evaluation are paid once.
- *So a change is scored by rows first,* then the sweep's cost per row, the
  forward's cost per row, and rejections last. `harness/rows.R` scores a driver
  run against a baseline as `(forward + 6 rows) / 7`.
- *A bar sits at ε, on the quantity that binds:* the gradients' spread under
  tolerance nudges. `J`'s error at `3e-5` is 2000 times inside ε.
- Most tests below were scored on the forward and on `J`, before this was
  plain. §7 and §8 re-score theirs in rows.

The scripts:
- `harness/step_program.R` reads saved SCM runs.
- `harness/ark_prototype.R` is the R driver that reproduces the SCM's Cash–Karp
  bit for bit, on v12 (`lib_v12t`). Its new options are `ATTEMPT_LOG`,
  `KNOT_SEED`, `TOL_SOIL`, `ATOL`, `LATE_FROM`, `REGIME`, `TIMES`, and
  `SWITCH_BORN` with `SWITCH_UNTIL`.
- `harness/attempts.R` reads the driver's attempt logs,
  `harness/crossings.R` its crossing logs and refusal runs, and
  `harness/soil_steps.R` what bounds its steps. `harness/soil_chain.R`
  integrates the soil chain alone, `harness/warm_start.R` sets its steps
  against the coupled run's, and `harness/chain_creation.R` finds where
  creation shuts. `harness/rows.R` scores driver runs in rows.
- `harness/replay_timing.R` times the invader's replays on `PLANT-98`.
- `harness/j_window.R` reads `harness/layer_heights.R`'s every-node runs, and
  `harness/error_structure.R` the thinned schedules.
- The driver's outputs and logs are in `docs/measurements/grid-dynamics/`.

## The symptoms

| | symptom | root cause | state |
|---|---|---|---|
| 1 | steps: 17 683 on long drought, 3637 on the constant record (3951 on its resolved grid) | the soil's accuracy at the norm's tolerance through each rain-rate change | established; on pulsed records no cheap lever, under constant rain the implicit soil saves 66% (§7); the chain alone predicts the steps (§12) |
| 2 | 17.5–21% of attempts rejected | near knots, the controller's carried proposal; within a day after them, the soil's transient; far from them, the members' sign changes and near-empty pools | established; the chain alone's seeds remove 85% of the knots' rejections for 3.5% fewer member evaluations (§12), and with PI the rejections' cost falls from 18.2% to 9.3% of the run (§7). But a rejection turned into an accepted step is a row the sweeps pay: PI with the seeds costs a gradient run 5.8% more (§7). The first-day soil-bound ones are being tagged for class switches (§7) |
| 3 | the invader's first replay costs about two forwards | `run_mutant` re-runs the resident to keep its field | established; fixed on `PLANT-99` |
| 4 | `J`'s time error does not follow the tolerance under plant's default absolute tolerance | near-empty pools, and steps across members' sign changes | established earlier; the pools fixed by the tied tolerance, under which the error stays within 0.46·tol but changes sign between tolerances (§13) |
| 5 | gradients are a staircase in θ | sign changes sliding past the stages | established earlier; per-member events on a quintic interpolant remove it (§11) |
| 6 | the invader's node error changes sign under halving on uniform nodes | two opposite errors at the layer's top that shrink at different rates | established; the field part is the soil's for `J` and light's for the invader, and spreading each panel's leaf area removes the light part (`canopy-spread.md`) |
| 7 | the constant record rejects 16% with no knots | the soil's stability bounds its steps, and the step-size law cycles across the limit | established; the implicit soil pays there, and on the chain alone a PI law leaves 6 of 1009 rejections; coupled, PI saves 1.0% of a gradient run (§7) |
| 8 | on the pulsed records 59–61% of member-steps come after t = 25, where at most 6.1% of `J` is still to be earned | the tolerance and the spacing weight every time and node alike | established; a rule from a 54-node pilot saves 21–28% of a forward's member evaluations and as many rows at ≤ 0.08ε on three pulsed records, but a failing invader's pools are unstable on its loosened steps (§8) |
| 9 | the sign-change refusal costs 3.4× | it refuses after the window too | half established: limited to the window it keeps `J` for 43% less; limited to the cohort that earns `J` it does not. Superseded by per-member events (§11) |
| 10 | the soil binds 84–91% of the steps | the soil chain's own answer to each rain change, resolved at every member's leaf solve | established; the members alone need about half the steps, and the chain implicit and out of the norm together is untested (§10) |
| 11 | the per-member split that cures the gradients costs 4× | the driver evaluates every member to read one | established: 10.2% of a forward's leaf solves and 12.4% of a replay's on a quintic interpolant, for 3.4–6.4× less spread under nudges (§11); its cost in the sweeps not measured |
| 12 | the partitioned step's corrected couplings stall at 1e-4 to 5e-4 | the held collar's first-order deficit in the dry spells' water budget; the drift toward a fixed bias as the members' tolerance tightens is not traced | the partition killed (§13), and dead for another reason: in the dry spells the coupling is an algebraic loop; the drift likely a defect in the corrections, not traced |
| 13 | the sweep costs 2.5–2.7 forwards, so a run with every gradient spends 74% in sweeps; spreading each panel's leaf area slows it 1.7–3.4× | not profiled | open; being profiled |

## 1. The steps

**Reproduced** (`step_program.R`):
- *Rain days hold 44% of the steps,* 5.6 each, rising with depth: 2.9, 4.0,
  5.9 and 9.6 steps by depth quartile.
- *Dry intervals hold the rest,* about 3.5 + 2.8 ln(length in days) each
  (R² 0.42).
- *The constant record takes 3637 steps,* against 9133 to 21 921 on the
  pulsed records. Its resolved grid takes 3951 (§7).
- *Nodes barely move it:* 17 338 to 18 807 steps from 54 to 429 nodes.
- *The tolerance moves it weakly:* steps go as tol^−0.15.

**Traced** (the driver's ladder, `ck_u108_*` logs):
- *The soil binds 84–91% of accepted steps* at every tolerance from `1e-2` to
  `1e-7`.
- *At `3e-5` those steps are accuracy-limited:* 8.4% of steps start within 0.8
  of the soil's explicit stability limit (1.5% under the tied tolerance),
  against 37% at `1e-2`.

**Hypothesis: the soil's accuracy is more than `J` needs.** The soil binds the
steps, and the stepper scope found its stages carry little of `J`'s time error.

**Test: the soil's tolerance weights ×10, alone.** Under the tied tolerance
(`ATOL=1e-4`). J* = 12.6687135, Cash–Karp at `1e-8`:

| tol | soil weight | accepted | member evaluations | `J − J*`, relative |
|---|---|---|---|---|
| `3e-5` | 1 | 17 684 | 7.06e6 | −1.26e-5 |
| `3e-5` | 10 | 13 937 | 5.70e6 | −2.39e-5 |
| `1e-5` | 1 | 21 106 | 8.42e6 | +0.52e-5 |
| `1e-5` | 10 | 16 385 | 6.69e6 | −1.23e-5 |

- *Refuted.* The looser soil adds 1–2e-5 to `J`'s error, as much as the error
  it had. At a matched error it saves about 5%: ×10 at `1e-5` against ×1 at
  `3e-5`.
- *The earlier reading came from plant's default absolute tolerance.* There the
  pools' uncontrolled error swamped the soil's, and one run's `J` is a draw of
  ±2e-4. Under that tolerance the same ×10 seemed free (`ck_u108_*_soil10` logs).
- *The driver's tied run matches today's SCM run:* 17 684 accepted steps against
  17 683.

**Root cause.** The steps are what the soil's accuracy costs through each
rain-rate change, and that accuracy reaches `J` in proportion. So the record
predicts the cost, but no weight on the soil buys accuracy cheaply. What
remains is the method's efficiency on the soil, or the tolerance itself: `J`'s
time error at `1e-4` is 3.7e-5, under 2e-3 of its ε. The method's efficiency
means the chain implicit and out of the norm, together (§10).

## 2. The rejections

**Reproduced.** The SCM rejects 18–21% of attempts on every record and at every
node count (`step_program.R`); the driver rejects 17.5% (`attempts.R`).

**Traced** (one attempt log, `attempts.R` on `ck_u108_3e-5_v12t`):
- *Near knots, the soil rejects.* 85% of rejections start on a knot (40%) or
  within the day after one (45%), and the soil rejects 94% of these.
- *Between 1 and 10 days after a knot there are 32.*
- *In dry spells longer than 10 days, members and storage reject.* Members
  reject 266 there, storage 115 and the soil 2, at a rate of 25–27%.
- *By the change, first attempts at a knot are rejected* at 0.51 where rain
  starts, 0.51 where it falls, 0.39 where it rises and 0.07 where it stops.
- *A rejected first attempt at a knot is usually the whole day to the next
  knot* (median 1.0 day). The step accepted from there has a median of 0.31
  days.

**Hypothesis: the carried proposal.** At a rain-rate change, the controller's
first attempt is sized for the rain before it.

**Test: cap that attempt at the size last accepted after a knot of the same
kind** (`KNOT_SEED=1`), alone:
- *Rejections on knots fall from 1185 to 2.*
- *But accepted steps within a day of a knot rise from 7763 to 10 077,* and
  member evaluations by 7.9%.
- *`J` moves 3.8e-5,* within one run's draw at this tolerance.
- *Under the tied tolerance the same seed costs 5.7%* (§12).

**Root cause.** The mechanism holds, but it is not the inefficiency. The
rejected attempt is the controller's probe of the soil's new time scale, and a
cheap one: its estimate shrinks the step straight to the size the soil
accepts. A seed from the last knot of the same kind is too small, so the steps
must grow back. The cost is in the accepted steps (symptom 1). The far
rejections are where the time error's sources sit (symptom 4).

## 3. The invader's replay

**Reproduced.** On the uniform runs the invader phase takes 1.7–1.8× the stand's
forward (`step_program.R`).

**Traced.** `SCM::run_mutant`'s first call re-runs the resident with its field
kept, to record it (`scm.h`, `run_mutant`). It does so even when the stand was
just run with its trajectory recorded.

**Test** (`replay_timing.R`, uniform 108, tied tolerance at `3e-5`):
- the forward takes 114.8 s;
- the first replay 203.5 s;
- the second 91.0 s;
- the invader's `J` is identical in all three.

**Root cause, confirmed.** The first replay holds a second resident forward. It
is about 12% of a run with every gradient of both roles, and paid once per
resident, so it is small across a landscape of invaders.

**Fixed** on `PLANT-99` (aornugent/plant#99). A run that keeps its states also
keeps the field each evaluation built, where no evaluation reads it, and the
first invasion walks that.
- Under the same load, the first replay takes 139 s against 300 s on `PLANT-98`,
  and the walk itself is unchanged.
- `J`, the stand's gradient and an invader's at `lma` × 0.95 are bit-identical.
- A recorded forward holds 130 MB more after it, about 7.4 kB a step, and the
  peak over a forward and an invasion does not move.

## 4–6, established earlier

- *`J`'s time error* (`docs/archive/scope-imex-stepper.md` §7; the spec's step
  2(a)).
  - Near-empty pools refilling after a sign change carried a survival error as
    large as the offspring part, because their tolerance weight is absolute in
    kg. The tied tolerance fixes that: `J` within 0.46·tol from `1e-3` to
    `3e-5`.
  - The steps across members' sign changes remain. Cash–Karp's estimate
    under-reports them 4.6× (median), and every treatment tried cost 3–4×:
    refusal, split, and locate-and-step. §9 limits the refusal to the window,
    and §11 prices the split at its real cost, 10.2% of a forward.
- *The staircase* (the spec's step 5). The kinks bind curvatures (a chord over
  ±1e-2) and small differences (0.004–0.007 in the invader's `lma` elasticity
  at ±1e-6).
- *The step program's path dependence.* A one-ulp change in the absolute
  tolerance (`3e-9` against `1e-4 × 3e-5`) moves `J` by 4.7e-7 at `3e-5`.
- *The node error* (`docs/measurements/creation-grid.md`, *What sets the node
  error on long drought*). The field adjoint map splits its field part by
  channel: `J`'s is the soil's, the invader's light's
  (`docs/measurements/field-adjoint-map.md`). Spreading each panel's leaf area
  over its members' heights removes the invader's: the field part of 108 → 215
  goes from +0.380 to −0.034 (`docs/measurements/canopy-spread.md`).

## 7. The constant record's rejections

**Reproduced.** On its resolved grid (`const_Gbf16`, 150 nodes; uniform nodes
lump the founders there) the SCM rejects 15.8% of attempts, 739 against 3951
accepted. The driver reproduces both counts and `J` to every printed digit.

**Traced** (`attempts.R` on the driver's attempt log, `ck_const_Gbf16_3e-5`):
- *The soil rejects 666 of the 739;* storage 25, members 47 and an accumulator 1.
- *The soil binds 91% of the accepted steps,* and 83% of them start within 0.8
  of its explicit stability limit, 24% beyond it. On long drought under the tied
  tolerance it is 1.5%, and none beyond.
- *A rejected attempt is a median 1.23 times the size then accepted* from its
  start.
- *The tolerance barely moves the steps:* every weight ×100 after t = 25
  saves 1.7% of them (§8), against 17% on long drought.

**Hypothesis: on the constant record the soil's stability, not its accuracy,
bounds the step,** and the controller grows each step past the limit and is
rejected back. Constant rain holds the soil near a steady drainage, whose
fastest mode is stiff, with no rain change for the accuracy to follow.

**Test: the soil held under the limit (`METHOD=held`), and taken implicitly
(`METHOD=ark`),** each alone:

| method | tol | accepted | rejected or thrown | member evaluations | `J − J*`, relative |
|---|---|---|---|---|---|
| Cash–Karp | `3e-5` | 3951 | 739 | 3.76e6 | +6.1e-9 |
| | `1e-5` | 4111 | 840 | 3.96e6 | +1.0e-8 |
| held under 0.8 of the limit | `3e-5` | 4610 | 52 | 3.74e6 | −1.2e-8 |
| ARK, the soil implicit | `3e-5` | 1413 | 266 | 1.30e6 | +3.7e-7 |
| | `1e-5` | 1808 | 270 | 1.61e6 | −1.4e-6 |

J* = 289.2738962 is Cash–Karp at `1e-8` (6726 steps).

- *Held under the limit, the rejections fall from 739 to 52.* The steps are
  shorter and more, so the cost does not move.
- *Taken implicitly, the soil no longer bounds the step:* 64% fewer steps and
  66% fewer member evaluations at `3e-5`, with `J` within 4e-7, and 59% fewer at
  `1e-5`. Cash–Karp's error is far below what any objective needs, and
  tightening its tolerance threefold adds 4% to its steps.
- *ARK's error does not fall with its tolerance* (+3.7e-7, then −1.4e-6), as on
  long drought, where its embedded estimate missed the layers' error on long
  steps. Both are below 1e-4 of ε.
  - The strategy reply's reading: an embedded formula that is not stiffly
    accurate misjudges a stiff component in either direction. With the chain
    out of the norm it would not matter, and a check against one tight run
    replaces it.
  - It also calls both values inside `J*`'s uncertainty. On this record they are
    not: Cash–Karp's own errors are 6e-9 and 1e-8.

**Root cause, confirmed.** Constant rain holds the soil where its stiffness, not
its accuracy, bounds an explicit step. The controller grows each step past the
stability limit and is rejected back, and the step count is set by the limit,
not the tolerance. Here the implicit soil pays, as it did not on long drought,
whose steps are accuracy-bound (`docs/archive/scope-imex-stepper.md` §7, step 4).
A run tells which regime it is in from `h|λ_soil|/β` at its steps' starts: 83%
at 0.8 or more here, 1.5% on long drought.

**The controller's law, on the chain alone** (`soil_chain.R` with `CONTROL`,
against the chain at `1e-10`; `soil_chain_control.log`). odelia's law never
shrinks a step after accepting one and grows it by `0.9 r^{−1/6}`. `shrink`
floors that factor at 0.2 instead of 1 and takes the rejection's exponent, 1/5;
`pi` adds to `shrink` the previous ratio's term at exponent 0.04:

| record | law | tol | accepted | rejected | moisture error, at knots median / max, or at the end |
|---|---|---|---|---|---|
| constant | odelia | `3e-5` | 4886 | 1009 (17.1%) | 3.3e-5 |
| | shrink | `3e-5` | 4880 | 760 (13.5%) | 1.4e-5 |
| | pi | `3e-5` | 4898 | 6 (0.1%) | 1.3e-5 |
| long drought | odelia | `3e-5` | 16 447 | 2925 (15.1%) | 7.9e-7 / 9.7e-5 |
| | shrink | `3e-5` | 16 157 | 3166 (16.4%) | 9.0e-7 / 1.2e-4 |
| | pi | `3e-5` | 17 500 | 1910 (9.8%) | 5.5e-7 / 5.6e-5 |
| | pi | `6e-5` | 15 877 | 1910 (10.7%) | 1.1e-6 / 1.6e-4 |

- *Under constant rain the rejections are the law's.* An integral law grows each
  step past the stability limit and is cut back; the PI term damps that cycle,
  and 6 of 1009 rejections remain, at 4898 accepted steps against 4886 and a
  smaller error. The tolerance does not move the steps there (4892–4898 accepted from
  `3e-5` to `1e-4`).
- *On long drought PI turns a third of the rejections into accepted steps* for
  the same attempts, with a smaller error. At matched error it saves about 4% of
  attempts, interpolating between `3e-5` and `6e-5`. Its rejections stay at
  1910–1960 at every tolerance to `1e-4`; the chain seeds (§12), which remove
  the knots' rejections, are untested with it.
**On the coupled driver** (a pre-registered test; `pi/`, the driver's `CONTROL`
with `PI_BETA`, `PI_ALPHA`, `PI_SAFETY`, the chain seeds regenerated at each run's
tolerance). Tied tolerance throughout:

| run | accepted | rejected or thrown (on knots) | member evaluations | `J − J*`, relative |
|---|---|---|---|---|
| long drought, odelia, `3e-5` | 17 684 | 3912 (1238) | 7.06e6 | −1.26e-5 |
| PI, `3e-5` | 18 815 | 2905 (1123) | 7.10e6 | −2.3e-6 |
| PI + chain seeds, `1e-4` / `3e-5` / `1e-5` | 15 846 / 18 964 / 22 562 | 1663 / 1936 / 2451 (159 / 190 / 213) | 5.73e6 / 6.84e6 / 8.19e6 | −4.4e-5 / +8.2e-6 / −4.2e-6 |
| Gustafsson's gains + chain seeds, `3e-5` | 21 411 | 1414 (190) | 7.49e6 | −1.2e-6 |
| constant, odelia / PI / Gustafsson's, `3e-5` | 3951 / 3974 / 3987 | 739 / 229 / 83 | 3.76e6 / 3.36e6 / 3.25e6 | +6.1e-9 / +2.1e-8 / −5.7e-9 |

- *Killed by its pre-registered bar.* PI removes 69% of the constant record's
  rejections against the 90% asked, and the ±5% nudge moves its `lma` elasticity
  by 0.0062 against the baseline's 0.0035, both within 0.21 of ε/3 and two
  samples each. Gustafsson's gains remove 89% there, but cost 15% more at matched
  error on long drought.
- *What it buys.* On long drought PI with the seeds saves 5.3% at matched error
  by the bound reading (7.2% by medians, 11.1% on the monolith's monotone
  bracket), mostly the seeds' (PI alone costs 0.6% at `3e-5`). Its fixed-step
  `lma` elasticity moves 0.0015ε. On the constant record PI saves 10.6% of member
  evaluations, Gustafsson's 13.4%.
- *In rows it loses* (`harness/rows.R`, `rows.log`). PI turns rejections into
  accepted steps, and each is a row the walk and the sweeps pay again:

  | long drought, `3e-5` | forward | rows | a gradient run |
  |---|---|---|---|
  | the tied baseline (962 505 rows) | 0 | 0 | 0 |
  | the last knot's seed (§2) | +5.7% | +14.1% | +12.9% |
  | the chain seeds (§12) | −3.5% | +1.4% | +0.7% |
  | PI | +0.6% | +6.4% | +5.5% |
  | PI + chain seeds | −3.1% | +7.3% | +5.8% |
  | Gustafsson's gains + chain seeds | +6.0% | +21.4% | +19.2% |
  | constant: PI / Gustafsson's | −10.6% / −13.4% | +0.6% / +0.8% | −1.0% / −1.2% |

  The ±5% triples give the same, +7.3% rows for −3.1% forward. PI's `J` error is
  smaller (RMS 5.9e-6 against 9.7e-6 over the triple, `pi/tables_matched.txt`),
  but `J` is 2000 times inside ε, so that buys nothing. The rejections it
  removes were 9% of one forward, while the rows it adds are paid six times.
- *Under constant rain the coupled run cycles where the chain alone settles:*
  185 of PI's 229 rejections are a cycle of five accepted steps and one rejected
  at `h|λ|/β` 0.78–1.05, the soil binding, where the chain alone settles on one
  step at ratio 0.445. The reply's two cures, both untested: Gustafsson's gains
  only where `h|λ|/β` exceeds 0.8, which a run reads for free; or the chain
  implicit wherever the forcing says it is near-constant.
- *The rejections left with PI and the seeds* cost 9.3% of the run's member
  evaluations, against the baseline's 18.2% (`pi/tables_taxonomy.txt`):
  - 661 at a crossing inside the attempt (storage 437, mass 145), which no law
    removes and the split does (§11);
  - 798 soil-bound attempts on the first to fourth step within a day after a
    knot, mostly where rain falls or starts, whose ratio jumps about 8× after a
    growth of only 1.03. An estimate smooth in `h` cannot jump so. The reply
    reads them as kinks: members leave the lower-end class a median 0.26 days
    before their upward crossing, so each onset brings class switches, and each
    is a `C⁰` kink in that member's draw and so in the chain's rate. Being
    tagged by whether a class changed inside the attempt;
  - 199 overshoots after a small ratio, 190 on knots (mostly storage-bound, 124
    of them at a crossing) and 9 at the stability limit.

**The sign changes of `J`'s error are the crossings'** (`pi/tables_chain.txt`). On
the chain alone, under either law on long drought and under PI on the constant
record, the global moisture error is nearly proportional to tol over four
decades: the median `|err|/tol` drifts at most fourfold (a log-log slope of
0.66–0.99), and its mean never changes sign. The coupled `J`'s error changes sign
within ±5% of tol, and falls with tol once each crossing is split (§11).

## 8. The cost after `J` is earned

**Reproduced** (`j_window.R`, every node). R(t) is the share of `J` still to be
earned after t; the pulsed records are on uniform 108 at `3e-5`, the constant
record on its resolved grid, `const_Gbf16`.

| record | R(15) | R(20) | R(25) | R(30) | R(35) | member-steps after 25 | after 30 |
|---|---|---|---|---|---|---|---|
| long drought | 87% | 18% | 5.0% | 0.77% | 0.084% | 61% | 44% |
| long wet | 86% | 20% | 5.1% | 0.83% | 0.071% | 60% | 44% |
| dry | 85% | 22% | 6.1% | 0.72% | 0.058% | 60% | 43% |
| episodic | 90% | 25% | 6.0% | 0.48% | 0.039% | 59% | 39% |
| constant | 54% | 16% | 3.4% | 0.55% | 0.062% | 37% | 25% |

- *One window on every record.* From 1% to 99% of `J` is earned between
  t = 13.4–13.7 and 29.2–29.3 on the pulsed records, and between 10.8 and 28.5
  on the constant record.
- *The steps are spread evenly in time,* 34–38% after t = 25 on every record.
  Member-steps come later, since every node carries on to the end. The constant
  record's are earlier because its grid's nodes cluster at the founders' front.
- *Nodes born after 20 hold at most 2.4e-4 of `J`.* The cohort born before 3.6
  holds 78–100% of it.
- *A pilot gives R(t).* On long drought, uniform 54 at `1e-3` reads it within
  1–4% at t = 15–35. On the constant record a uniform pilot lumps the founders,
  as uniform grids do there, and reads `J` as 0.0008.

**Traced.** An error made at t, in a step or in a node born at t, changes `J`
only through what is earned after t, so R(t) bounds its weight. The controller
holds every state to one relative tolerance at every time, and the schedule
spaces nodes alike throughout.

**Hypothesis: the steps and nodes past the window cost `J` nothing measurable.**

**Test 1: every tolerance weight ×100 on steps that start after t = 25**, alone
(the driver's `LATE_FROM=25`, at `3e-5` under the tied tolerance):

| record | | accepted | member evaluations | `J − J*`, relative | `J`'s elasticity in the trait `lma`, frozen steps |
|---|---|---|---|---|---|
| long drought | baseline | 17 684 | 7.06e6 | −1.26e-5 | −4.98010 |
| | ×100 after 25 | 14 730 | 5.13e6 | −1.87e-5 | −4.98034 |
| constant | baseline | 3951 | 3.76e6 | +6.1e-9 | −4.40100 |
| | ×100 after 25 | 3883 | 3.63e6 | +4.7e-9 | −4.40100 |

- *Long drought:* member evaluations fall 27%. `J` moves 6e-6 and the
  elasticity 2.4e-4, 0.003 of the `lma` elasticity's ε as a scale.
- *Constant:* they fall 3.5%; `J` moves 1.4e-9 and the elasticity under 1e-5.
  Its steps are bound by the soil's stability, not its accuracy (§7), so a
  looser tolerance buys little.
- The elasticity moves `lma` as a trait, through TF24's hyperparameterisation,
  by central differences at 1e-5 on each run's own accepted steps. It is not
  the gradient's partial in `lma`.

**Test 2: nodes born after b = 10 thinned fourfold** (every fourth kept, 48
nodes; `error_structure.R`).
- `J` falls 2.5%. Refuted.
- Of the 2.6% move back to uniform, 2.3% is the field part at the first
  cohort's nodes: lumping the later cohorts changes the water and light seen by
  the cohort that earns `J`. Those later cohorts hold 0.8% of `J`.
- So a node's own share of `J` understates its weight. R(b) bounds it, and
  R(10) is all of `J`.

**Test 3: thinned fourfold after b = 25** (79 nodes).
- `J` moves −1.9e-4 relative, 0.008ε in `ln J`, and member-steps fall 11.7%.
- Every quantity of both roles outside the small four moves a median
  0.005–0.006ε, at most 0.07ε (the invader's `recruitment_decay`). Uniform
  108's own move to 215 nodes is a median 0.21–0.22ε.

**Root cause, confirmed on long drought.** The controller spends a third of its
steps after t = 25 on every record, and on the pulsed records three fifths of
its member-steps, where at most 6.1% of `J` is still to be earned. Weighted by R(t), those steps and the
nodes born there can be coarsened at no measurable cost: 27% of member
evaluations in time and 12% of member-steps in nodes.

**Caveats.**
- Tests 2 and 3 are on long drought; the window is measured on all five
  records.
- A shared grid's window must cover every invader in the analysis; one that
  reproduces later widens it. Not measured.
- R(t) bounds the weight. How far a tolerance or a spacing can be loosened is
  measured only by tests 1 and 3.
- Where stability binds the steps, as on the constant record, the time weight
  buys little.

**The window as a rule, set from a pilot** (a pre-registered spike; `window/`,
`harness/invader_window.R`, `window_rule.R` and `window_test.R`, the driver's
`WEIGHT`, and `run_record.R`'s `PROGRAM` and `INVADERS`).

*The windows,* as the years by which R falls to 0.1, 0.01 and 1e-3, then `J` or
`J′`. An invader's walk keeps its states when the run records its trajectory, so
`R′` comes exactly from one walk:

| record | the stand | lma ×0.5 | lma ×2 | hmat ×0.5 | hmat ×2 |
|---|---|---|---|---|---|
| long drought | 22.6/29.2/34.5 · 12.7 | 21.4/28.6/34.1 · 1877 | 5.0/15.7/24.8 · 2e-21 | 17.5/25.3/31.2 · 164 | 30.4/35.9/39.2 · 2e-8 |
| long-wet | 22.6/29.3/34.4 · 18.4 | 21.2/28.4/33.9 · 2682 | 4.8/15.2/21.3 · 2e-21 | 17.2/24.9/30.9 · 198 | 30.9/35.9/39.2 · 6e-8 |
| dry | 23.2/29.3/33.7 · 1.19 | 21.3/27.4/33.4 · 790 | 18.2/26.4/31.5 · 1e-20 | 18.8/25.1/32.1 · 71 | 28.1/33.3/38.5 · 2e-10 |
| episodic | 23.5/29.2/33.6 · 1.98 | 21.5/27.8/32.1 · 541 | 28.0/33.9/38.9 · 1e-19 | 18.4/25.4/30.2 · 68 | 29.2/34.0/38.7 · 1e-9 |
| constant | 21.6/28.5/34.0 · 289 | 18.4/25.9/32.6 · 6e4 | 4.1/4.3/4.5 · 2e-21 | 6.2/6.5/6.6 · 100 | 35.9/39.2/40.0 · 0.017 |

- *A failing invader earns late:* hmat ×2 on every record, and lma ×2 on episodic.
- *Residents at ×1.1 earn later:* their R is up to 1.23–1.51× θ₀'s on long
  drought and 1.39–1.80× on episodic.

*The pilot.* 54 nodes at `1e-3` reads the stand's R within 10% wherever
R ≥ 1e-3, on every record (4.2–9.8%), for 0.25–0.32 of a forward's member-steps.
The 27-node pilots miss dry's tail by 25%. The node count matters and the
tolerance barely does, the reverse of §12's creation gaps. No pilot reads lma ×2,
which raises on most of them. On the constant record the 53-node causal grid at
`1e-3` reads R within 1.1%.

*Rule A,* set from the pilot alone:
- Every tolerance weight of a step starting at t is multiplied by
  `F(t) = 1/clamp(R̂(t)/R₀, r_min, 1)`, where `R̂` is the pilot's largest R over the
  stand and lma's range ends, `R₀ = 0.1`, and `r_min = 0.01`, where the soil's
  stability starts to bind (§10).
- Nodes after the window are spaced `⌊√F(b)⌋` lattice spacings apart, by the
  square law.
- The weight passes 1 from t = 22.5 (long drought, long-wet), 23.5 (episodic) and
  21.6 (constant), and reaches 100 at t = 33.5–34.5. It keeps 82–84 of 108 nodes.

*What it buys, against the unweighted run* (`window/window_test.log`):

| record | weight alone | weight and nodes | `J` moves | the fixed-step `lma` elasticity moves |
|---|---|---|---|---|
| long drought | −22.8% | −27.7% | −2.4e-6 | 0.0014ε |
| long-wet | −20.5% | −25.2% | +1.2e-6 | 0.0001ε |
| episodic | −20.8% | −25.4% | +1.5e-6 | 0.0013ε |
| constant | −3.6% | | −6e-11 | 0.0000ε |

On full-gradient runs the weight saves 22.7% on long drought and 21.0% on
episodic. It saves as many rows as forward member evaluations (`rows.log`):
22.7%, 21.2% and 21.0% on long drought, long-wet and episodic, 25–28% with the
thinning, and 1.9% on the constant record. Every quantity of both roles moves
at most 0.016ε under the weight and 0.078ε under the thinning (`a_st3`, one of
the small four); the noise floor, the driver's program against plant's own, is
1e-4ε.

**Not a pass: the walk fails, not the accuracy.** On episodic the lma ×2
invader, 12× outside rule A's protection, raises a non-finite density on rule A's
program at t = 32.57. Its steps there are 31–38 days, against 5–11 unweighted.
Rule B adds hmat's range ends to the protection. It saves only 10.0–12.2%, and
the same walk raises at t = 36.28, on a 22-day step where the unweighted
program took 3.4.
- *Refuted:* the invader's share `R′` as what a shared grid must protect.
  Invaders 8.7–21× outside rule A's protection move only 0.002–0.06ε.
- *Root cause, from a measurement already on record:* the walk fails by its
  pools' stability, not by accuracy. For `y′ = −y/τ` Cash–Karp's fourth stage
  goes negative past `h = 2.16τ`, and the step is unstable past `3.73τ`: 15 and
  26 days at the pool's relaxation time `τ_s`
  (`docs/archive/scope-imex-stepper.md` §3). Rule A's steps there are 31–38
  days. The stand's own pools that relax that fast are late members' near-empty
  ones, under the ×100 weight and the absolute floor, and a walk has no error
  control.
- *The cures, from the strategy reply, untested:* the invader's members
  sub-stepped where `h/τ_eff > 2`, with `τ_eff = τ_s + S_max/(u⁺ + u⁻)` read
  for free, so that nothing triggers at θ′ = θ; and a cap of 15 days on the
  stand's steps as a safety net, which protects every invader's pools since
  `τ_eff ≥ τ_s`. A guard on invaders reads their stability, never their share.

## 9. Which crossings carry `J`'s time error

**Hypothesis: the crossings that carry `J`'s time error are the cohort's that
earns `J`,** born before 3.6, on steps before t = 25. Step 4 traced the error to
the offspring of members born before 3.5, accruing over t = 12–20
(`docs/archive/scope-imex-stepper.md` §7). On the tied baseline at `3e-5`
(`crossings.R` on its replay's `CROSS_LOG`) those crossings are 1212 of 9235,
and their clusters span 149 days against 654 for every member's. Capping steps
at 0.05 days across them is about 3000 steps, against 13 000.

**Test: step 4's refusal (`SWITCH_DAYS=0.05`) limited to those crossings
(`SWITCH_BORN=3.6`, `SWITCH_UNTIL=25`),** under plant's default absolute
tolerance as step 4 ran it. `J − J*` relative, member evaluations in brackets:

| refusal | `1e-3` | `3e-4` | `1e-4` |
|---|---|---|---|
| none | −2.4e-4 (3.70e6) | +1.04e-3 (4.07e6) | +8.1e-4 (4.64e6) |
| every member | −3.0e-4 (15.05e6) | −1.0e-4 (15.40e6) | −1.7e-5 (15.88e6) |
| born before 3.6, before t = 25 | −3.4e-4 (5.03e6) | −3.5e-5 (5.40e6) | +3.1e-4 (5.96e6) |
| every member, before t = 25 | | | −2.4e-5 (9.12e6) |
| born before 3.6, at every time | | | +3.2e-4 (6.60e6) |

- *Refuted as stated.* The cohort's crossings carry about 60% of `J`'s error at
  `1e-4`: limited to them, the refusal takes it from +8.1e-4 to +3.1e-4, where
  every member's takes it to −1.7e-5. Members born later carry the rest, though
  they hold 7% of `J`.
- *But the window holds for the crossings.* Limited to steps before t = 25, the
  refusal for every member keeps `J` (−2.4e-5 against −1.7e-5) for 43% fewer
  member evaluations, and the cohort's refusal at every time is the cohort's
  before t = 25 (+3.2e-4 against +3.1e-4).
- *This ran under plant's default absolute tolerance,* whose near-empty pools
  the tied tolerance fixes, so the later members' part may be their pools'.
  Under the tied tolerance `J` stays within 0.46·tol, though its error changes
  sign between tolerances (§13), and what the crossings still break is the
  gradients' continuity in θ, not measured here.

## 10. What sets the soil's steps

**Reproduced** (`soil_steps.R` on the tied baseline at `3e-5`):
- *Three quarters of the steps start within a day of a rain change.* A rain
  interval takes 5.6 steps; a dry interval 6.4, 3.6 of them in its first day.
- *Every layer binds,* and members and storage bind 28% of the dry intervals'
  steps.
- *Inside an interval, a soil-bound step's error ratio has median 0.36 on rain
  intervals and 0.085 in dry ones,* and the next step grows ×1.0 and ×1.2. On
  rain intervals the soil is at its accuracy; in dry ones the controller is
  still growing the step.

**Hypothesis 1: the soil's steps are its own answer to the forcing, not the
plants'.**
- *Test:* the chain alone, with no uptake (`soil_chain.R`): 16 447 accepted
  steps against 17 684 coupled.
- *Confirmed.* The plants add 7%.

**Hypothesis 2: the cost is drainage's power-law tail.** After rain a layer
drains as `θ ∝ t^{−1/(q−1)}`, and its rate falls as one over the time since the
rain.
- *Test:* the chain in `u = θ^{1−q}`, in which a layer draining with nothing
  above it moves linearly in time: 20 275 steps. Dry intervals take 7% fewer,
  rain intervals 38% more.
- *Refuted.* The cost is the answer on rain intervals, whose wetting fronts `u`
  sharpens.

**Stiffness and instability.**
- *On the pulsed records the soil relaxes about as fast as the forcing moves
  it:* `h|λ|/β` has median 0.27–0.45 on soil-bound rain steps and 0.07–0.56 on
  dry ones. With no scale to separate, an implicit soil buys no longer steps,
  which is why ARK did not pay on long drought (step 4).
- *Under constant rain the drainage is steady and stiff, and nothing moves:*
  stability binds, and ARK pays (§7).
- *Stepped at the members' pace, the explicit soil is unstable.* With the soil
  and the flux accumulators out of the error norm (`TOL_SOIL=1e6 TOL_ACC=1e6`),
  21% of steps start beyond its stability limit and `J` falls 10.7%.

**What the members need on their own.** In that run the members bind 95% of
9176 steps: 2.5 per rain interval and 3.7 per dry one, in 4.14e6 member
evaluations against 7.06e6. That bounds their demand from above, since the
unstable soil disturbs them.

**Untested: the chain implicit and out of the norm, together** (the strategy
reply's first lever). Each change was tested alone, and each alone fails:
- *Implicit, in the norm:* an implicit chain removes the stability bound, not
  the accuracy bound, so held to the norm's tolerance its steps stay. Step 4's
  ARK kept the chain in the norm and paid 9% at matched `J`, under plant's
  default absolute tolerance.
- *Out of the norm, explicit:* unstable (above).
- *Together* they leave the members' own steps: toward the 9176 above against
  17 684, less ARK's lower order. The reply prices it at 1.6–1.9× on everything
  that walks rows. The chain's error would then be checked against one tight
  run, since ARK's embedded estimate misjudges it (§7).

**Root cause.** Five scalar equations, the soil chain answering each rain
change, set 93% of the steps. A monolithic step pays the members' leaf solves
at each of them, and the chain cannot step at the members' pace, where it is
unstable.

## 11. The crossings' cure, priced

- *The mechanism is the grid reply's*
  (`docs/archive/oracle-response-grid-controller.md`). A node's crossing of zero net production is a kink at any step size. On one
  grid the gradient's error is first order in the crossing step's length, and
  the second derivative between the gradient's jumps is off at zeroth order.
- *Its cure was set aside at four times a plain replay:* split each crossing
  member's update at its crossing, and differentiate the crossing's time.
- *That cost is the driver's.* Each of the split's member evaluations calls
  `patch$derivs`, which evaluates every member. On the per-pool scale's grid at
  `1e-4` the split re-integrated 9229 members in 167 256 full evaluations, 18
  each with the crossing found to `|P| < 5e-11`. The replay's own 80 232
  evaluations held 4.38e6 member evaluations (`split_u108_1e-4_lma_±1e-4.log`).
- *Counted per member, the split adds 3.8%,* the reply's estimate of 4%, on
  the per-pool scale's grid at `1e-4`. It needs plant to evaluate one member in
  a step's interpolated field.
**Test: per-member events at their real cost** (a pre-registered spike;
`events/`). A plant probe (`node_rates_probe.patch`) evaluates one member in a
step's field, bit for bit as `patch$derivs` does. Each member whose net
production crosses zero inside a step is split there: the crossing located on
an interpolant of the step, the member re-integrated on the sub-steps, and the
step's end corrected. Long drought, uniform 108, tied tolerance:

| | `1e-4` | `3e-5` |
|---|---|---|
| plain replay, leaf solves | 5.04e6 | 6.00e6 |
| split on a cubic interpolant, replay / adaptive forward | +7.2% / +5.9% | +6.2% / +5.2% |
| split on a quintic interpolant, replay / adaptive forward | +12.4% / +10.2% | +12.4% / not run |
| `J − J*`, relative: plain / cubic / quintic | +3.7e-5 / +1.6e-4 / +4.0e-6 | −1.3e-5 / +9.0e-5 / +1.0e-6 |

- *The split needs an interpolant of the step's order.* On a cubic through the
  step's ends, the field the split members read is off by more than one error
  weight on 10 of 60 crossing steps for the soil (up to 23) and on 23 of 60 for
  the other members (up to 30). Halving only the crossing steps shrinks the
  cubic split's move 10–13× each time, as `h⁴`. On a quintic through a half-step
  midpoint `J`'s error falls with the tolerance, 9–12× nearer `J*` than plain.
- *Where the cost goes* (cubic, `1e-4`): locating 2.3%, sub-steps 4.1%, the
  corrected step ends 0.9%, for 9233 members split in 726 of 14 845 steps. The
  quintic's midpoints add 5.2%. The 3.8% above missed the field's boundary-node
  solve and the corrected step ends.
- *The spread under the nudges:* seven tolerances within 5% of `1e-4`, the
  largest move from the `1e-4` run in ε/3, the standard deviation in brackets
  (`events/runs/final_nudges.txt`):

  | quantity | plain | split, quintic |
  |---|---|---|
  | `ln J` | 0.003 | 0.001 |
  | `a_dG1` | 1.048 (0.37) | 0.174 (0.06) |
  | `d_I` | 1.261 (0.38) | 0.282 (0.11) |
  | `a_dG2` | 0.906 (0.27) | 0.138 (0.05) |
  | `lma` | 0.477 (0.15) | 0.059 (0.02) |

  The kink is 70–85% of the spread: the split cuts the standard deviation
  3.4–6.4×, and its means are within 0.4 ε/3 of plain's. `1e-5`, the record's
  remedy, costs about 41% more leaf solves; the split buys the same stability at
  `1e-4` for about a quarter of that. The plain arm is reverse mode on
  `lib_v12t`; the split arm central differences at `r = 1e-3` on each run's
  frozen structure, which agree with reverse mode on the plain grid within
  0.12 ε/3.
- *The chord* (`lma` on the `1e-4` grid, `events/runs/final_chord.txt`): plain's
  second difference is 2.8–4.4ε below the wide chord's −44.0 at `r` from 3e-4 to
  1e-3; the split's is within about 1ε of it, and its elasticity is flat in `r`
  within 0.06 ε/3.
- *Crossings changing step* under a change of `lma`: 1–3 at ±1e-5, 4–7 at ±1e-4,
  about 78 at ±1e-3 and 650 at ±1e-2, each moving `J` by 1e-8 (cubic) or 5e-9
  (quintic).
- *Grazing.* Member 5, 3.1% of `J`, dips to `P = −2.9e-4` at a rain-onset knot at
  t = 17.15, its two crossings either side of the knot's step boundary; the dip
  vanishes within +1e-5 in `lma`. With one cut per member step the frozen
  structure jumped 5.8e-7 in `ln J`, 2–3 ε/3 in `d_I`. Cutting a step twice where
  a member's production has an interior dip makes it continuous to the noise
  floor, for 0.06–0.6% more.

**Verdict: close to a pass.** The spread passes clearly. The cost misses the
10% bar by 0.2–2.4 points, all of it the quintic's midpoints. Counted, not
measured: a stage-based interpolant, a shared boundary-node solve and locating
from the stages would bring it to about 8%, or 3% with a pair whose fourth-order
interpolant is free.

**Root cause, confirmed:** the gradients' spread under tolerance nudges is the
kinks' (§4–6). Split at each crossing on an interpolant of the step's order, the
spread falls 3.4–6.4× and `J`'s error falls with the tolerance.

**Not measured:** the reverse sweep's cost with the split (estimated +10–20%), the
invader with it, the relaxation offset's and the cost scale's elasticities, and
other records. Building it into odelia's step and sweep and plant's member rates
is about 0.9–1.3k lines in 4–5 stacked changes; the spike's report lists what the
recording and the tape must hold.

**From the strategy reply, untested:**
- *A fourth-order interpolant, free.* The +10–20% is the midpoint's: it adds a
  row for every member on every crossing step. An interpolant of the error
  estimate's order leaves only the split members' sub-rows, under 2% of the
  sweeps. It can be fitted to Cash–Karp's six stages and its end derivative,
  or taken from a pair that publishes one (Dormand–Prince or Tsitouras 5(4),
  whose real stability boundary of about 3.3 against 3.73 costs steps only
  where the explicit chain is stability-bound). Accept a crossing step only at
  a ratio of 0.5 or less, as insurance.
- *Locate on the step's interpolant, never on its raw stages,* which are `O(h²)`
  wrong as point values; a second location on the split solution's
  interpolant takes the crossing to `O(h³)`.

## 12. What the chain alone tells the schedule

The chain alone costs 2.4e-4 of a forward: 19 372 attempts at 1.4 µs each in
C++, 27 ms against plant's 114.8 s (§3), on a loaded machine. In R it takes 6 s.
What it can set before the run (`warm_start.R` against the tied baseline at
`3e-5`, `chain_creation.R`):
- *The step program: yes.* A record's intervals take 5.61 steps each alone and
  6.03 coupled, correlation 0.76, and 89% of intervals differ by at most one
  step. The first accepted step after each knot, coupled over chain alone, has
  median 1.00 (10–90%: 0.87–1.3).
- *Each knot's first attempt: yes.* Taken as the coupled run's first attempt,
  the chain's first step would pass the error test at 96% of knots, by the
  local error's fifth order. Where it passes it is a median 0.69 of the longest
  step that would; the coupled run's own first accepted step, after its
  rejections, is 0.73. On the driver (`CHAIN_SEED`, then `attempts.R`):

  | | the tied baseline | §2's last-knot seed | chain seeds |
  |---|---|---|---|
  | accepted | 17 684 | 19 999 | 17 916 |
  | of them within a day of a knot | 10 423 | 12 716 | 10 650 |
  | rejected or thrown | 3912 | 2696 | 2888 |
  | of them on a knot | 1238 | 5 | 189 |
  | first attempts rejected where the rain falls, rises, starts, stops | 58, 42, 51, 6% | 0, 0, 0, 0% | 5, 5, 4, 2% |
  | member evaluations | 7.06e6 | 7.47e6 | 6.81e6 |
  | rows | 962 505 | 1 098 303 | 976 047 |
  | a gradient run (`rows.R`) | | +12.9% | +0.7% |
  | states evaluated past the inflow switch, the loss clamp, the floor | 162, 320, 85 | 1, 2, 1 | 0, 1, 0 |
  | `J − J*`, relative | −1.26e-5 | +3.6e-7 | −1.73e-5 |

  Under the tied tolerance the last knot's seed removes every rejection at a
  knot but costs 5.7% more member evaluations, since its steps are too short and
  must grow back. The chain's removes 85% of them and saves 3.5%, but its rows
  rise 1.4%, so a gradient run comes out even. The other rejections are
  unchanged; most fall within a day of a knot, on the soil.
- *Which bound holds on the soil: yes.* The chain alone starts 4.9% of its steps
  at `h|λ|/β ≥ 0.8` on long drought and 99.4% under constant rain, against the
  coupled Cash–Karp runs' 1.5% and 83% (§7).
- *Where creation shuts: no.* A newborn in full light establishes with
  probability 0.99 when its top layer is at `θ ≥ 0.15`, and 0 at 0.1; its
  roots read that layer alone. Without uptake, long drought's top layer never
  dries that far, so the chain alone shuts creation nowhere.

**Where creation shuts.** The 429-node run has 78 gaps in creation, 6.96 of 40
years. A newborn in full light on the 108-node run's soil finds 71 of them and
91% of their time. The members' uptake makes the gaps, and their shade adds the
rest.

**What finds the gaps:** coarser runs' own creation records, against the
429-node run's. Cost is member-steps over the 108-node run's 1.18e6, rejected
attempts counted, unlike `creation-grid.md`'s accepted steps alone.

| run | cost | gaps | the gap time found | openings within a day |
|---|---|---|---|---|
| chain alone, newborn in full light | 2e-4 | 0 | 0 | none |
| 27 nodes at `1e-3` | 0.15 | 68 | 91% | 85% |
| 27 nodes at `3e-5` | 0.24 | 74 | 97% | 94% |
| 54 nodes at `1e-3` | 0.30 | 67 | 92% | 86% |
| 54 nodes at `3e-5` | 0.49 | 76 | 99% | 97% |
| 108 nodes at `3e-5` | 1 | 78 | 99% | 100% |

- *Tolerance matters more than nodes.* At `1e-3` the runs miss gaps of 3–6 days
  before t = 10 and put those openings 26–65 days out. At the run's tolerance,
  27 nodes place 94% of openings within a day.
- *Every coarse run misses one gap,* a quarter of a day at t = 6.08.

**Root cause.** Creation shuts where the newborn's top layer is dry or shaded.
The dryness is the members' uptake, and the chain alone sees the rain, not the
stand. A schedule probe for the creation grid must carry the members, and at
the run's tolerance a quarter of the forward's members places the windows.

## 13. The partitioned step, priced

**The test** (a pre-registered spike; `partition/`). The members take Cash–Karp
steps under their own error control, with the soil and its accumulators out of
their norm. Inside each member step the soil chain is sub-stepped by Cash–Karp
at `SOIL_TOL` and lands on the member stages' times, where the members read it.
The soil's uptake comes from a coupling:
- `held`: each node's collar suction, root network, leaf area and density held at
  the step's start, each layer's draw re-derived from the collar (phylloptim's
  `uptake_at`);
- `exact`: every leaf re-solved at each soil stage, the members held; `exactx`,
  the members carried on their rates at the start instead;
- corrections of `held`: `stage` (the hold refreshed at each member stage),
  `stagelin` (each collar extrapolated linearly in time), `defect` (the soil's
  end corrected by the stages' quadrature of the uptake each member stage
  evaluated, against the held), and `pc` (a corrector pass on the uptake
  interpolated between the predictor stages' holds).

It passes at `|J − J*| ≤ 1.26e-5` on at most 4.94e6 leaf solves, or `3.66e-5` on
4.16e6: the monolithic run's errors at `3e-5` and `1e-4`, for 30% fewer.

**Result: killed** (`partition/frontier.txt`; long drought, uniform 108, tied
tolerance, the soil at `3e-5` unless stated):

| scheme | member tol | member steps | leaf solves, of the monolith's at `3e-5` | `J − J*`, relative |
|---|---|---|---|---|
| monolithic | `1e-3` / `3e-4` / `1e-4` / `3e-5` | 11 001 / 12 759 / 14 845 / 17 684 | 0.62 / 0.72 / 0.84 / 1 | −4.0e-4 / +3.3e-6 / +3.7e-5 / −1.3e-5 |
| held | `3e-5` / `1e-6` | 6076 / 10 703 | 0.36 / 0.67 | +0.136 / +0.074 |
| held, on the monolith's steps | | 17 684 | 0.82 | +0.111 |
| exact, members held | `3e-5` | 6141 | 0.36, and 2.5 in the soil | +1.25e-2 |
| exact, members carried | `3e-5` / `1e-5` | 6133 / 7163 | 0.36 / 0.42, and 2.5 / 2.9 in the soil | −3.0e-4 / −2.2e-4 |
| stagelin + defect | `1e-4` / `3e-5` / `1e-5` / `3e-6` / `1e-6` | 5294 … 10 750 | 0.30 / 0.36 / 0.42 / 0.53 / 0.67 | +5.6e-4 / +1.1e-4 / −2.4e-4 / −3.4e-4 / −4.9e-4 |
| stagelin + defect, soil at `1e-6` | `3e-5` | 6130 | 0.36 | +1.2e-4 |
| pc + defect | `3e-5` / `1e-5` | 6121 / 7142 | 0.66 / 0.78 | −4.4e-5 / −1.4e-4 |
| pc, one pass / two, no defect | `3e-5` | 6125 / 6138 | 0.65 / 0.95 | +8.0e-3 / −2.1e-4 |
| held / defect, member steps capped at a day | `3e-5` | 16 349 / 16 335 | 0.79 / 0.79 | +2.3e-2 / +4.0e-4 |

- *The held collar is first order:* its error falls 1.8-fold for 1.76 times the
  steps, so `3.7e-5` would take about 10⁷ member steps.
- *The nearest pass,* `pc + defect` at `3e-5`, is 22% cheaper than the monolith at
  `1e-4` at 1.2 times its error. Its frozen-step `lma` elasticity is −4.98452,
  against the monolith's −4.98010: 0.05ε.
- *At errors near 5e-4, 0.02ε,* `stagelin + defect` at `1e-4` takes half the leaf
  solves of the monolith at `1e-3`.

**Where the coupling's error is** (`held` at `3e-5`; `partition/defects.log` and
`partition/where.log`, from `defects.R` and `where.R` on the runs' step logs):
- *In the soil's water budget.* The held collar draws 2.85% too little water.
  Correcting only the budget at each step's end removes 91% of `J`'s error; the
  rest is the members reading too wet a soil inside the step. Taking 0.1% of
  the uptake out of the monolithic run raises `J` by 0.22%.
- *In dry spells.* Their steps carry 108% of the deficit and rain steps −8%,
  since a wetting soil makes the held collar over-draw. 49% of the deficit is
  10–30 days after rain and 32% later, 95% of it in the top layer. At a step's
  end the deficit is a median 0.5% on steps of 1–3 days, 2.2% on 3–10 and 5.2%
  beyond.
- *The mechanism:* in dry soil the collar sits close to the layer's suction, so
  the gradient that draws water is small. Held while the soil dries, the collar
  wipes it out, where the leaf would move its collar to keep drawing.
- *In the first cohort:* the nodes born at 0 and 0.37 carry 94% of `J`'s excess.
- *Not in the crossings:* the held collar errs +11.1% on the monolith's own steps,
  and refusing long steps across a sign change of net production leaves the
  corrected couplings' residuals in place.
- *The exact control's own error is the members' change over the step:* held, the
  members' uptake misses 0.12% on steps over 3 days.

**Not explained: the corrected couplings drift to a fixed bias.** Their error
does not fall as the members' tolerance tightens. `stagelin + defect` moves
steadily from +5.6e-4 at `1e-4` through zero to −4.9e-4 at `1e-6`, and
`pc + defect` from −4.4e-5 to −1.4e-4 between `3e-5` and `1e-5`; the nearest
pass sits near that zero. The soil's tolerance does not move it, nor does the
crossing refusal. Where the residual is large (`|ΔJ| ≥ 1e-4`), 93–114% of it is
in the members born before 0.5, the first two nodes' output 2–12e-4 low; the
two-pass corrector's sits in those born 0.5–3.6 (97%).

**Likely a defect in the corrections, not traced.** As the members' steps
shrink, each corrected coupling tends to the coupled step, so an error that
stops falling is an inconsistency, not an order. The strategy reply's two
suspects:
- *Stage six read late:* Cash–Karp's sixth stage sits at 7/8 of the step,
  before the fifth at its end. Not in the stepper: every coupling lands the soil
  on 7/8 and on the end in time order and hands each stage its own soil
  (`split_stepper.R`, `STAGE_BY_TIME`).
- *The nodes' weights held:* the newest nodes' quadrature weights change with
  time, and a hold freezes them across the soil's sub-steps. Untested.
- *`exact`, carried, is no witness,* though the reply counts it as biased: its
  error falls 1.36-fold for 1.17 times the steps, about second order.
- *Two runs would decide:* the member steps and the soil's sub-steps both forced
  onto the coupled run's steps, where the scheme must reproduce it to the
  exchange's small error; and the soil's draw read from the coupled run's
  recording while the members keep long steps. The first isolates the
  mechanics, the second the side. Being root-caused, since a scheme that does
  not converge as its steps shrink has a defect until shown otherwise.

**What it costs:** `uptake_at` is 1/140 of a leaf solve (734 instructions against
104 640), not the 1/1000 assumed; `held`'s calls add about 5% to the leaf solves.
The stepper sources the driver as it was at 2ad8059, from the spike's checkout.

**Root cause.** In dry spells the soil dries by the members' own uptake, through
a collar the leaf moves to keep drawing. Holding either side across a member
step leaves a first-order error in the water budget, which `J` amplifies. A
partition would have to move both the collar and the members within the step
to high order, which is the coupled step.

**The verdict, re-read.**
- *The bar was 2000 times inside ε.* At errors near 5e-4 in `J`, 0.02ε,
  `stagelin + defect` takes half the monolith's leaf solves, and `pc + defect`'s
  `lma` elasticity is 0.05ε off. The gradients' spread was not measured.
- *It is dead for another reason* (the strategy reply). In the dry spells the
  coupling is an algebraic loop: the collar is set at once by the soil it draws
  from. Co-simulation calls this direct feed-through, where extrapolated
  coupling is order-limited whatever each side's solver does. There nothing is
  fast, and the coupled step is already cheap (6.4 steps per dry interval,
  §10). The multirate gain was in the rain intervals, where an implicit chain
  takes it more simply (§10).

## What the record supports, and what it does not

- *Supported: a gradient run's cost is its rows and its sweeps.* The walk and
  the sweeps are six of its seven forwards, and they pay rows. Scored so, PI
  with the seeds costs a gradient run 5.8% more, while the window rule saves as
  many rows as forward evaluations (§7, §8).
- *Supported: the record predicts the cost.* Steps per rain day follow its depth,
  dry intervals their length, and nodes and tolerance move it little.
- *Supported: the forcing sets which bound holds on the soil.* Pulsed rain keeps
  it accuracy-bound; constant rain makes it stability-bound, where the implicit
  soil pays (§7). A run reads which from `h|λ_soil|/β` at its steps' starts.
- *Not supported, on `J`: a cheap accuracy lever in the forcing.* The soil's
  accuracy reaches `J` in proportion, and a naive seed from the record costs
  more than the controller's own probing.
- *Supported: one window of the goal, on every record, read by a pilot.* A
  54-node pilot reads it within 10%, and a rule from it saves 21–28% of a
  forward, and as many rows, on three pulsed records for at most 0.08ε in any
  quantity of either role (§8). The crossings after it carry none of `J`'s time
  error (§9).
- *Not supported: the invader's share as the guard for a shared grid.* A failing
  invader's pools are unstable on the loosened steps, though its share says it
  is safe (§8). Its stability is the guard.
- *Supported: the error's sources are the members' and the stand's, located by
  a run.* They are the sign changes, the near-empty pools, the layer's top and
  the fronts. The field adjoint map reports the node error's field part by
  source panel, time and channel for +12% of a sweep.
- *Not supported: the cohort that earns `J` as the only one whose crossings
  matter.* Later cohorts carry 40% of `J`'s time error at `1e-4` under plant's
  default tolerance (§9).
- *Supported: the soil chain sets the steps on its own* (§10). The members
  need about half of them. The chain implicit and out of the norm together,
  untested, would leave the steps to the members.
- *Not supported: drainage's tail as the soil's cost.* Integrated where that
  tail is linear, the chain takes more steps.
- *Supported: per-member events make the gradients reproducible and `J`'s error
  fall with the tolerance,* for 10.2% of a forward's leaf solves on a quintic
  interpolant (§11). Their cost in the sweeps is not measured; on a free
  fourth-order interpolant the reply counts it under 2%.
- *Supported on long drought: with each panel's leaf area spread over its
  members' heights, uniform halving reports its own node error* (median ratios
  3.6–3.9, companions 0.93–1.09; `canopy-spread.md`). Not on the constant
  record, whose front still needs nodes. Its sweep runs 1.7–3.4× slower.
- *Not supported: a partitioned step.* Holding the collar across a member step
  leaves a first-order error in the dry spells' water budget, and the
  corrections stall at 1e-4 to 5e-4 (§13). At a bar of ε they might have
  passed, but there the coupling is an algebraic loop, and the gain was in the
  rain intervals, where an implicit chain takes it.
- *Partly supported: the constant record's rejections are the step-size law's.*
  On the chain alone PI leaves 6 of 1009; coupled, it removes 69%, cycles where
  the chain alone settles, and saves 1.0% of a gradient run (§7).
- *Supported: the sign changes of `J`'s error under tol are the crossings',* not
  the controller's (§7, §11).
- *Supported: the chain alone sets the step program, the knot seeds and the
  soil's bound before the run,* at 2.4e-4 of a forward. Its seeds remove 85% of
  the rejections at knots, and a gradient run comes out even (§12).
- *Not supported: the chain alone as a probe for the creation grid.* The members
  make the gaps; a pilot at the run's tolerance with a quarter of its nodes
  finds 97% of their time (§12).
- *One runtime defect was plain,* the invader's first replay repeating the
  resident's forward, and is fixed on `PLANT-99` (§3).

**Where the results point** (the strategy reply's synthesis; a hypothesis to
design against, not a result).
- *Every new result reads one object:* a continuous extension of the global
  step, of the step's order. Events read it to re-integrate a crossing member.
  Invaders read it between recorded instants, over weeks on the window's long
  steps.
- *So one global step carries the chain and the fields.* The members' aggregate,
  goal-weighted accuracy sets it, and the chain is implicit so that it never
  sets the step alone.
- *Inside it, any member, the stand's or an invader's, is refined against the
  dense output* when its own reading says so: a crossing, a class switch, a
  pool's `h/τ_eff`, an invader's own estimate. The fields are still formed from
  every member at every global stage, so the dry spells' loop is never opened.
  Only single paths are corrected, and the fields they fed lag by their own
  share of one step.
- *The dense output is part of the discretisation,* a fixed linear map of the
  recorded stage derivatives, and the sweep treats it so.

## Next probes, each one variable

Running:
- the 798 tagged by whether a member's class changed inside the attempt (§7);
- the sweep profiled: its cost per row by component, and the spread leaf area's
  slowdown (symptom 13);
- the partition's drift root-caused (§13).

Rows first:
- the chain implicit and out of the norm together, scored in rows and in the
  gradients' spread under nudges (§10);
- goal-oriented rows: the window's weight per component and time from the
  pilot's sweep, and the understory tiered against the canopy's exact step
  (§8);
- rule A with the invader's members sub-stepped where `h/τ_eff > 2`, and the
  price of the 15-day cap (§8);
- per-member events on a free fourth-order interpolant, in the forward and the
  sweeps (§11).

Then the cost per row:
- the inner solve warm-started as an index-1 algebraic variable: each attempt's
  first stage from the last accepted step's end, later stages from the stage
  before, and the three nested roots as one Newton system. It cuts the
  forward's cost per row, and the sweep's if its implicit-function solve is the
  same system.

Then the rest:
- the Hessian's cost: chords of gradients (about 68 forwards for five traits,
  both roles) against forward-over-reverse (about 26), or forward second
  differences once events make `J` smooth on one grid (about 10);
- if the chain implicit fails: its whole step program as each leg's proposal,
  scored in rows (§7, §12);
- the step-size law chosen by regime from `h|λ|/β`, scored in rows (§7);
- the introductions moved by a quarter spacing, R2's other knob, on uniform 108
  and graded G1.
