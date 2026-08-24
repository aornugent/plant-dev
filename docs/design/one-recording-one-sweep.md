# One recording, one sweep

## Triage: 3 — cross-package headers with external consumers

`odelia` is a published package; `DifferentiationTargets`, `Solver::get_history_*`
and `ad_initial_state()` are R-visible or contract-visible. The requirement also
arrived as solution-verbs ("use `DifferentiationTargets`", "consolidate idioms"),
which is the other Tier-3 trigger.

## Requirements ledger

**R1 — one way to take d(functional of a trajectory)/d(parameters).** Today two,
sharing no code: `compute_jacobian` (whole run on one tape, System cached on the
Solver) and `solve_adjoint_over_widenings` (one step per tape, System lifted per
recording). `plant` and `phylloptim` reference the first **zero** times.

> *Challenged upward:* "use `DifferentiationTargets`" is a mechanism, not an
> outcome. `DifferentiationTargets` selects **inputs**; in reverse mode one sweep
> returns every input's row whether it was asked for or not, so input selection
> buys nothing on the path it sits on. Read as the outcome — *one canonical
> entry point* — the request is met by deleting it, not adopting it. Confirm.

**R2 — a Strategy declares a forward model plus its differentiable inputs, and
nothing else.** Today it also owes `ad_initial_state()` (a contract member plant
declares none of), and the column predicate is spelled 4× in `tf24_strategy.h`
with the same walk repeated 3× in `Patch`.

**R3 — no number moves.** Standing rule for this campaign. Baseline: plant
3283/0/0/13 and 679/0/0/5, phylloptim 2421 checks + 223 golden + 1455/0/0/1,
odelia 408/0/0/3. odelia was 415 until increment 0 removed a test file whose
seven expectations went with the function it tested; a suite losing a number is
allowed only when the deletion accounts for it exactly.

**R4 — quantities.** 117 recorded steps; 3 census metrics; 62 table entries of
which 15 are `no_column`, so 47 gradient columns per species; 6 rate evaluations
per step per sweep. A recording is a model evaluation; a sweep is arithmetic.

**Scarce resource.** Derived from R4: it is not CPU — `row_batch` already
collapsed the per-metric cost, so metrics two and three cost almost nothing — and
it is not memory, which step-wise taping already bounds at one step. What is
scarce is **places where two spellings of one fact can disagree while both
compile.** Every defect this campaign actually found was of that class, and every
one produced a plausible finite number rather than an error. In this pathway
there are nine:

| # | the one fact | its second spelling | sites |
|---|---|---|---|
| 1 | a recorded trajectory | `ode_step_record` unpacked into loose `(states, times)` | 4 unpackings |
| 2 | a widening, and when it happened | `recorded_widening` + `recorded_insertion`, bridged by `insertions_of` | 1 construction, 4 bridges |
| 3 | the tape discipline | `clearAll` per recording (sweep) vs `newRecording` on a cached System (calibration) | 2 headers, ~20 lines of cross-reference |
| 4 | record-once-sweep-many | `vector_jacobian_product` vs `xad::computeJacobian` | 2 engines |
| 5 | a stored trajectory | `Solver::history` (`vector<System>`) vs `recorded_state(k)` | 2 recorders |
| 6 | "the gradient has a direct term" | plant's R doc + a comment at the fold site | 0 guards |
| 7 | which parameters have a column | the predicate `zero_means != no_column` | 4 spellings + 3 walks |
| 8 | the widenings partition the recording | `state_segments`' check, re-run per call and skippable | 4+ calls |
| 9 | the differentiable inputs | `ad_parameters()` + `ad_initial_state()` | 1 of the 2 is unused by plant |

## The floor

Land the two free subtractions: delete `forward_derivative` (zero shipped
callers; its one novel content, the deduced-return-type `static_assert`, is
already live in `implicit_value` and stated in AGENTS.md), and fold the column
predicate to one `constexpr` index array.

**Fails R1 and R2.** It clears rows 7 and part of 9 and touches none of 1–6, 8 —
which is where every plausible-wrong-answer path lives. Do it anyway, first: it
is pure subtraction and it makes the next step smaller.

## Candidates

**A [first thought] — move 6, Pólya with witnesses. One `trajectory` type.**
Commitment: a recording is one validated object, never a set of correspondents.
Pays rows 1, 2, 5, 8. Costs one new name, and it must *replace* `ode_step_record`
rather than sit beside it. Wins when the witnesses are already in hand and
disagree — they are: five spellings, and `recorded_widening` is built at exactly
one site (`scm.h:581`) where the time is already available, so `insertions_of`
exists only to recover a fact that was in scope when it was dropped.

**B — move 3, move the system boundary. One entry point covering seed→sweep→add.**
Commitment: you cannot obtain a swept parameter row without the seed that
produced it. Pays rows 3, 4, 6. Costs: odelia gains a functional protocol. Wins
when the direct term is the live hazard — it is: nothing guards it, and plant
states its existence in two places and adds it by hand in one.

**C — move 2, record→replay. Seeds attach at any recorded step.**
Commitment: a gradient is a seeded recording swept once; the final-state census
is the one-seed case and a trajectory loss is the many-seed case. Pays rows 3, 4,
6 **and covers calibration**, which is what lets Way A be deleted rather than
demoted. Costs: the seed container. Wins when every functional in hand is a sum
of per-step terms — and all four are (`least_squares`, `sum_of_squares`,
`sum_final_state`, `final_state`).

**Winner: A then C.** Eliminations: B is C restricted to one seed at the last
step, so it is not a competitor but C's degenerate case; choosing B would leave
calibration alive as a second path and R1 unmet. A is not optional under C — the
seed container is keyed by recorded step, so without one recording type there is
nothing for the key to name, and the signatures stay wide.

The mechanism C needs is already built and already proven. `extra_splits` stops
and resumes the sweep at arbitrary steps, and `test-gradient-ladder-identity.R`
asserts the pieces compose **bit for bit**. Nothing adds to lambda at the cut.
C is that hook, one step further, and the associativity test becomes the
zero-seed case of it — the same assertion, no coverage lost.

## The commitment

**A gradient is a seeded recording swept once.**

Kept true by structure, not by comment:

- `trajectory` validates its own partition at construction, so `be_at_step`
  cannot be reached with a recording whose widenings do not cover it, and the
  check stops being re-run per call.
- the widening carries its time from the one site that records it, so
  `recorded_widening` and `insertions_of` have nothing left to do.
- seeds are keyed by recorded step against that object, so a seed at a step the
  recording does not have is refused at construction rather than ignored.
- the direct term cannot be forgotten because the entry point that returns the
  parameter rows is the one that formed the seed: both come from one recording of
  the outputs, and there is no signature that hands back one without the other.
- one tape discipline, because nothing caches a lifted System — the lift stays
  inside `state_and_parameter_adjoints`, where the requirement is.

## Kill question

*The assumption whose falsity makes this unnecessary:* that one mechanism can
serve both a final-state census and a multi-point trajectory loss.

Argued from the ledger: it fails if a live functional is not a sum of per-step
terms, because then no per-step seed exists to attach. Every functional odelia
has is such a sum — `least_squares` over `obs_indices`, `sum_of_squares`,
`sum_final_state`, `final_state`. The adjoint recursion with a local seed added
at each observation step is the textbook multi-point construction, and it is the
same arithmetic `extra_splits` already proves associative. **Survives.**

## What survives deletion

| name | the ledger line holding it there |
|---|---|
| `trajectory<W>` | rows 1, 2, 5, 8 |
| seeds keyed by step | rows 3, 4, 6 and the Way-A deletion |
| `row_batch` | already the only output-selection vocabulary; 46 references |
| `vector_jacobian_product` | row 4's survivor — it takes caller seeds, which `xad::computeJacobian` cannot, so it is a generalisation and not a re-implementation |
| `implicit_node.hpp` | untouched; a different concern (supplied derivatives) |

No new entry-point name: `solve_adjoint_over_widenings` gains the seed argument
and loses `extra_splits`. That is a signature change, not an addition.

## What this settles

- `DifferentiationTargets`, `codomain()`, `scalar_functional`, the cached System,
  `active_solver`, `tape`, `replay_schedule_`, `set_schedule()`, `run()`, and the
  hand-written copy constructor and `operator=` that exist *only* because of the
  `unique_ptr<Tape>` member (the class comment says so) — all unreferenced.
- `calibration.hpp`/`sweep.hpp` stop needing to be two headers: the split exists
  to keep a reader from mixing two tape disciplines, and there is one.
- `ad_initial_state()` leaves the System contract. The initial-state gradient is
  lambda at the first state, which the sweep already produces.
- The documented unbounded slot leak goes with the cache that caused it.

## What this makes hard

A functional whose per-step seed depends on the whole trajectory — a max, a ratio
of integrals — needs a forward pass to fix its coefficients before the sweep can
be seeded. Coped with by the recording itself, which is that forward pass; but it
is two passes where Way A was one.

Giving up the cached System costs one rebind and one Solver construction per
gradient call, against a full ODE solve per call. Expected to vanish. **Measure
before landing increment 3** — this is the only number holding Way A up.

## Kill condition

A functional that is not a sum of per-step terms *and* cannot be given its
coefficients by a forward pass. That hands back to Way A — whole-trajectory
taping — and nothing else in this design has to move.

## Increments

Subtraction, then scaffold, then capability. Each lands green with numbers
unmoved.

0. **Subtract.** `forward_derivative` and its test; the column predicate 4 → 1.
1. **Scaffold.** `odelia::ode::trajectory<W>`: validated at construction,
   absorbing `state_segments` and `insertions_of`; the widening records its time
   at `scm.h:581`; `recorded_widening` and `ode_step_record` deleted; the five
   loose-array signatures collapsed; plant's 4 unpackings and 4 bridges deleted.
2. **Capability.** Seeds keyed by step; `extra_splits` becomes the zero-seed case.
3. **Delete Way A.** Measure the lift first. Then route `compute_jacobian`
   through the one engine and remove everything under "What this settles".
4. **The heavyweight recorder.** `history`/`collect`/`get_history_*` — row 5's
   other half. R-facing and breaking; the user's call, not mine.
