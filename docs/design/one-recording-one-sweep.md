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
> buys nothing *on cost*. Read as the outcome — *one canonical entry point* — the
> request is met by deleting it, not adopting it. Confirm.
>
> **Narrowed on review.** "Selection buys nothing" was too broad, and there is a
> witness: a refusal today costs a metric's whole gradient, so a caller loses
> d/d(lma) because psi_crit sat at a bound. Selecting fewer inputs would dodge
> that. The requirement is real; selection is still the wrong mechanism for it —
> see row 11 and "Fundamentals questioned".

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
| 1 | a recorded trajectory | `SolverInternal::step_record` → projected to `times()`/`step_sizes()`/`recorded_state()` → **re-bundled** as plant's identical `ode_step_record` → destructured again to `(states, times)` | 3 projections, 1 re-bundle, 4 unpackings |
| 2 | a widening, and when it happened | `recorded_widening` + `recorded_insertion`, bridged by `insertions_of` | 1 construction, 4 bridges |
| 3 | the tape discipline | `clearAll` per recording (sweep) vs `newRecording` on a cached System (calibration) | 2 headers, ~20 lines of cross-reference |
| 4 | record-once-sweep-many | `vector_jacobian_product` vs `xad::computeJacobian` | 2 engines |
| 5 | a stored trajectory | `Solver::history` (`vector<System>`) vs `recorded_state(k)` | 2 recorders |
| 6 | "the gradient has a direct term" | plant's R doc + a comment at the fold site | 0 guards |
| 7 | which parameters have a column | the predicate `zero_means != no_column` | 4 spellings + 3 walks |
| 8 | the widenings partition the recording | `state_segments`' check, re-run per call and skippable | 4+ calls |
| 9 | the differentiable inputs | `ad_parameters()` + `ad_initial_state()` | 1 of the 2 is unused by plant |
| 10 | a recorded step's time and size | `Solver::solve_adjoint` reads `times()` and `step_sizes()` off the solver while taking `states` as an argument | kept agreeing by a length check |
| 11 | which input's row went missing | `record_report.at` names it and the graft computes the plant-side index, then spends it on a message and latches a string | 1 index computed, 0 kept |
| 12 | why a zero is a zero | declared statically per parameter (`zero_means`) *and* known dynamically by the run (the operating point, the drop report) | informative on 3 of 62 entries |

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

> **It is not a new type. It is already there.** `SolverInternal` holds
> `std::vector<step_record>` with `{time, step_size, state}`, and its accessor
> comment states the invariant this design was about to invent one for: *"out of
> the record it shares with the time and the size that reached it — so a caller
> cannot pair one run's state with another run's size."* `store_trajectory`'s
> comment goes further, recording that the two stores were **already** unified
> here once and why: *"One record cannot be mispaired, so nothing is emptied and
> nothing is repeated."*
>
> Then `get_times()`, `get_step_sizes()` and `recorded_state(k)` project that
> record back into correspondents, plant re-bundles them into an identical struct
> of its own — re-checking a pairing that was never broken — and the sweep API
> destructures them a third time. **So candidate A is a deletion, not an
> addition**: stop projecting. What survives is a validated *view* over the
> solver's records plus the model's insertions, which owns no storage and copies
> nothing; the only thing it adds is that constructing it is where the partition
> is checked.

**B — move 3, move the system boundary. One entry point covering seed→sweep→add.**
Commitment: you cannot obtain a swept parameter row without the seed that
produced it. Pays rows 3, 4, 6. Costs: odelia gains a functional protocol — it
would have to know what a census metric is. Wins when the direct term is the live
hazard: nothing guards it, and plant states its existence in two places and adds
it by hand in one.

> **Overturned on review, and the design got smaller for it.** The direct term
> needs no entry point and no protocol. `parameter_adjoint` is already an
> accumulator the sweep ADDS into — that is its documented contract, because a
> parameter is reached once per step and its gradient is the sum over the steps
> swept. So the direct term is simply its **initial value**, and the total
> derivative reads as what it is: the direct partial, plus the trajectory. The
> closing add-loop disappears, forgetting the term becomes the visible act of
> passing a zeroed batch, and odelia learns nothing about censuses. Landed
> already (`plant@f4a52088`), ahead of everything else here, because it needed
> none of it.

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

## The one rule

Two refusals sit under this whole surface, and neither is a preference. **Do not
tape the leaf's solve** — recording a root-find differentiates the solver's
iterations, not the model. **Do not tape the whole trajectory** — it does not
fit. Together they force record-and-replay: the model is re-run from recorded
state. And once a model is re-run, every seam asks one question and only one:

> **What did the run know here, and where is it written down?**

Every duplication in the ledger is the same answer to it — *a fact the run knew,
dropped, and reconstructed downstream*:

- `insertions_of` reconstructs a widening's time. It was in scope at the one site
  that recorded the widening.
- `state_segments` reconstructs the partition on every call. It was fixed when the
  recording was made.
- `Solver::solve_adjoint` reconstructs nothing but reads times from a second
  source, so the two can disagree (row 10).
- `Status` reconstructs the operating point from curvature and residual. The
  branch the solve took already knew it, exactly (T1).
- a shut collar's exit is not recorded, so `placement` works around its absence
  (T5).
- the graft's `missing()` reconstructs why a row is absent. The row layer named it.
- `Solver::history` re-stores what `recorded_state` already stores.
- the direct term was reconstructed at the end of the call, by a loop, when the
  recording that produced the seed had produced it too.

So the design is one rule — **record the fact where it is known, project it where
it is needed, never re-derive it** — and each increment is that rule at a
different seam. That is what makes it more than its parts: a reader internalises
one decision, and the trajectory type, the seeds-at-steps generalisation, T1, T5
and the direct term all follow from it rather than each needing its own argument.

It also makes the two hardest properties structural instead of documented, and
neither cost a new guard. A gradient cannot be taken against an unvalidated
recording, because the recording validates itself at construction. The direct term
cannot be forgotten, because it is what the accumulator starts at. Both fell out
of putting the fact where it was known.

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
- the direct term is the accumulator's initial value, so the total derivative is
  the arithmetic rather than a correction to it, and leaving it out is the visible
  act of passing a zeroed batch instead of a missing loop at the end.
- one tape discipline, because nothing caches a lifted System — the lift stays
  inside `state_and_parameter_adjoints`, where the requirement is.
- the sweep reads the recording and nothing else for its times and sizes, so
  there is no second source to check against.

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
| seeds keyed by step | rows 3, 4 and the Way-A deletion |
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

## TF24's declaration, and the projection around it

R2's other half. The 62-line table reads as boilerplate over `TF24_Pars` and is
not: C++ has no reflection, so one line per differentiable member is the floor,
and each line carries a fact nothing else knows — what an exact zero in that
column would mean. The `sizeof` assert makes the list total, so a member cannot
be added and silently miss the gradient. **The table is the declaration and it
stays.**

The boilerplate is the ~100 lines of projection around it, spread over three
classes, and the reason is a single mismatch: **the table is `constexpr` per
type, and four of its six projections are instance methods anyway.**

| today | reads from an instance? |
|---|---|
| `ad_parameters()` | **yes** — the addresses in *this* object. The hot path: once per recording, so ~117× per gradient. |
| `ad_parameter_names()` | no |
| `ad_parameter_zero_classes()` | no |
| `Patch::trait_adjoint_names()` | only `species.size()` — it walks species objects to read data identical for every one of them |
| `Patch::trait_adjoint_zero_classes()` | same |
| `Patch::trait_adjoint_size()` | already knows better: `species.size() * T::ad_column_count` |

Names and zero-classes are wanted **once per gradient**, at the R boundary;
addresses are wanted once per recording. That asymmetry is the whole design cue.
Four projections become `n_species × static table` with no `strategy_ptr()->`
dispatch and no per-species concatenation, and the reader learns one table plus
one accessor instead of six accessors on three classes.

Three smaller items in the same place:

- **`gradient_status::Kind::no_column` does not belong in `Kind`.** Its own
  comment says it is *"Declared on the parameter, never assigned to an entry"* —
  an enumerator that is structurally never a value of what the enum describes.
  `std::optional<Kind>` says it honestly, deletes the enumerator, and lets
  `-Werror=switch` stop checking an impossible case at every consumer. The
  `has_column()` predicate that increment 0 made single-sited is the converter
  that gives it away: writing one was the tell that the type was wrong, not that
  the predicate was scattered.
- **`ad_column_count` is a pure alias with exactly one caller** (`patch.h:1255`).
  Inline it.
- **T4 is smaller than the audit recorded and worth doing.** Only **three** of
  the fourteen leaf names differ — `b`, `c`, `g1_TF24`, against `stem_b`,
  `stem_c`, `cost_scale_TF24`. Renaming them makes all fourteen agree and lets
  `PLANT_TF24_LEAF_PARAMETER` drop its third argument, so fourteen table lines
  lose a redundant field. Breaking, R-facing. The comment beside the macro claims
  *"four of the fourteen"*, which is stale by one — a count in prose against a
  count in the table, which is the theme of the whole audit.

## Fundamentals questioned

Three premises this design rests on, tested rather than restated. One failed.

**Initial states.** `ad_initial_state()` leaves the contract, and for a better
reason than "plant has none": **lambda at the bottom of the recording already *is*
d(output)/d(initial state)**, produced whether it is asked for or not. plant even
generalises it — an insertion is state appearing mid-run, and the sweep already
transposes each insertion's map and accumulates its parameter rows, so odelia's
"initial state" is the degenerate case where all state appears at t0. A declared
list of seedable initial-state entries adds nothing except the ability to select a
subset of them, which is the next question. Survives.

**Parameter subsets. This premise was wrong.** I claimed selection buys nothing
because reverse mode returns every column per sweep. True on cost, and it misses
the live requirement: a refusal costs a metric's *whole* gradient, so a caller
asking for d/d(lma) loses it because `psi_crit` sat at a bound. Selecting fewer
inputs would recover it. So the requirement is real.

Selection is still the wrong mechanism, and the reason is row 11. The escalation
is three over-approximations deep, and the information to stop it at the first is
already computed:

1. a row is missing for input *i* → the whole value refuses its rows
   (`record_with_derivatives`, NOTHING PARTIAL);
2. the value refuses → the metric refuses (plant throws, or latches);
3. one species refuses → every metric refuses.

Step 1 is right *given* that `record_report.whole` is a boolean — but the report
also carries `at`, and the graft turns it into the plant-side parameter index
before using it in a message. A missing row for input *i* leaves input *i*'s tape
edge absent and every other input's intact, and the answer already carries a
status **per (metric, trait) entry**. So the shape for "every column but
`psi_crit`, and that one marked refused" exists today; what is missing is that the
index is thrown away. Attribution delivers what selection was buying, with no
selection threaded from R through plant into phylloptim's row request, and with
one answer shape regardless of what was asked.

Honest limit: attribution works where the report names an input. It does not where
the quotient itself failed — `implicit_root` losing an invertible slope kills every
row of the point at once. Even there the blast radius is the outputs that *read*
the point, and the objective at an interior optimum does not (the envelope
theorem), so it is narrower than a metric.

**Structural zeros and refusals — the sharpest of the three.** Asked "what if
there were no structural zero or refused parameter", the answer is: there almost
isn't one. Of 62 table entries, `zero_means` carries irreducible information on
**three**.

| declaration | entries | what it really is |
|---|---|---|
| `zero_undeclared` | 44 | the default. Declaring it says what not declaring says. |
| `no_column` | 15 | **the value that switches off the referee** — see below |
| `zero_slack` | 2 (`psi_crit`, `root_psi_crit`) | **state-dependent**, and the run knows it exactly from the operating point |
| `zero_structural` | 1 (`a_f3`) | a genuine static claim |

`zero_slack`'s own definition gives it away: *"Becomes non-zero at a state where
the constraint binds."* Whether a zero means slackness is a property of the
operating point the solve reached, and `rows.kind` is in hand at the very site
that would report it. Declaring it per parameter is T1's defect in another place —
a static re-statement of something the run knows exactly — and T6 is its other
half, the same fact declared on both sides of the boundary.

So **`gradient_status::Kind` is a good output vocabulary and a bad input
declaration.** A caller reading "this zero is undeclared, treat it as a finding"
is reading something valuable; the table declaring it for 44 parameters is not.
What survives is a column list plus one annotation on `a_f3`, with slack and
refusal supplied by the run. That deletes
`ad_parameter_zero_classes()`, `trait_adjoint_zero_classes()` and the
zero-classification loop — and it is this design's own rule applied one level
deeper than the design applied it, which is the strongest evidence for the rule
and a correction to the design in the same breath.

**`no_column` is not a category error; it is worse.** Naming a zero and omitting
it differ in exactly one way that matters: **a named zero is computed, so the
ladder polices it, and an omitted one is never computed, so nothing does.**
`a_f3` is the proof, and it is the only parameter enjoying that treatment. It is
declared `zero_structural`; it *does* reach an equation (`fecundity_dt` divides by
`omega + a_f3`); and the referee is `ladder_zero_outside_the_metric_support()`,
whose comment names the two rates it moves — `fecundity` and
`offspring_produced_survival_weighted` — so that *"a third rate would mean the
census's silence about the column is wrong."* The claim is a measurement.

Two consequences. First, **`zero_structural` is misnamed**: a_f3's zero is
relative to the current metric set, not to the model. The helper says so — *"would
be live on a fitness functional"* — so the declaration sits on the parameter while
its truth depends on the metric list, and nothing ties the two together.

Second, and larger: **eleven of the fifteen `no_column` entries are in a_f3's
situation and get none of that policing.** `no_column` is carrying five different
reasons at once —

| reason | entries |
|---|---|
| reaches nothing the metrics read — i.e. `zero_structural` | `a_p1`, `a_p2`, `S_D`, `var_sapwood_volume_cost`, `nmass_l/s/b/r`, `dmass_dN`, `d`, `p_50` (11) |
| slack at an interior optimum — i.e. `zero_slack` | `beta1` (1) |
| a recorded row would be wrong (0·−inf) — a *refusal*, not an absence | `eta`, `root_depth_shape_eta` (2) |
| not a differentiable real at all | `use_energy_balance` (1) |

— and two of the comments state the name they should be carrying. `S_D`'s reads
*"zero on any trajectory rather than on this one"*, which is `zero_structural`'s
definition verbatim. `beta1`'s reads *"slackness makes its row zero at an interior
optimum. Live at a pin"*, which is `zero_slack`'s — while `psi_crit` and
`root_psi_crit`, in the identical situation, are declared `zero_slack` and
computed. Same physics, two treatments, and the omitted one is the unverified one.

So the move is not to shrink the vocabulary but to **stop using its escape
hatch**: file those eleven as `zero_structural` and let the ladder police them,
which costs eleven columns in an accumulator whose width the sweep is indifferent
to. `no_column` then holds four entries with genuinely distinct reasons — and each
resolves elsewhere. The two `0·−inf` cases are refusals the run should report (and
T7 argues the limit is 0, so they may not even be that); `use_energy_balance` is
not a number and should not be an `S` in a table of differentiable reals. At which
point `no_column` is empty, the has-a-column partition goes, `column_count` and
`field_count` coincide, and `ad_parameters()` and `field_ptrs()` are one accessor.

**The counterweight, which matters.** These declarations are *checked*, not
commented: `test-gradient-ladder-declared-zero.R` asserts both directions — every
column the ladder declares zero comes back in a zero class, and every column the
sweep puts in one is declared, with no undeclared zeros permitted in the fixture.
So this is a simplification of verified machinery, not a bug hunt. The residual
risk is the one a declaration always carries: it is a licence to stop looking. A
`psi_crit` column that reads exactly zero because a row was quietly dropped is
explained away as slackness, which is precisely the substitution `zero_undeclared`
exists to prevent. Two parameters hold that licence.

## Naming the number, not the table

`zero_slack` is opaque because it is named for a borrowed mechanism —
complementary slackness — rather than for what the reader is holding. Two of the
three zero names have the same defect, and the rule that fixes all three is:
**name what the number means to the reader, not what the table did about it.**

| today | what it actually says | proposed |
|---|---|---|
| `zero_slack` | this parameter is a *limit*, and the operating point is away from it. Non-zero the moment the point sits on it. | `zero_until_a_limit_binds` |
| `zero_structural` | zero for **this metric set**, not for the model — `a_f3` moves two offspring rates and the census reads neither | `zero_for_these_metrics` |
| `zero_undeclared` | named for the absence of a declaration, which is a fact about the table | `zero_unexplained` |

Each proposed name says what a reader should *do*: expect it to change with state;
pick a different metric or trait; investigate. And the better vocabulary already
existed one layer out — the ladder's own referees are
`ladder_zero_at_an_interior_optimum` and `ladder_zero_outside_the_metric_support`.
**The tests named these things honestly and the declaration did not.**

## Answered, or unavailable — the axis `no_column` was hiding

Challenged: if a refusal is being added anyway, does declaring a structural zero
buy anything over letting the user ask and be refused, then choose other targets?

Mostly yes, and it splits the eleven. The question is not "is this parameter
wired" but **"is the derivative known to be zero, or is it unavailable?"**

- **Known zero** — `a_f3`, `S_D`, `nmass_*`, `dmass_dN`,
  `var_sapwood_volume_cost`, `a_p1`, `a_p2`, `p_50`, and `beta1` at an interior
  point. These are *answers*, and informative ones: "this trait does not move
  these metrics" is what a user optimising over it needs to learn. Refusing hides
  real information, and computing the column is what lets the ladder police the
  claim.
- **Unavailable** — `d` (*"no row in the leaf's supplied Jacobian"*), and `eta`
  and `root_depth_shape_eta` (a recorded row would be a wrong zero). Nothing is
  known here, so refusal is exactly right, and the user's outcome — ask, be
  refused, choose other targets — is the correct one.

So the challenge lands on three of the eleven and not on the other eight. What it
does dissolve is `DifferentiationTargets`: the outcome it was wanted for is
delivered by per-column refusal plus the column subsetting `stand_gradient()`
already does in R. Selection belongs where the user is, not seeded into the sweep,
and a reverse sweep is indifferent to how many inputs it carries.

**And the asymmetry worth naming.** For the fourteen leaf parameters this is
already *detected*, not declared: phylloptim fills unclaimed rows with
`util::na_value`, so an input nothing claims returns NA and the graft refuses it.
The forty-eight plant-only parameters have no equivalent default — they are seeded,
taped, and whatever the tape gives comes back, with 0.0 for "no edge reached me"
indistinguishable from 0.0 for "the derivative is zero". **That is the whole reason
a declaration exists at all**, and it is worth asking whether plant's own
parameters can be given phylloptim's NA-default instead, which would make eight of
these declarations detections and leave `zero_for_these_metrics` to the parameters
whose zero is a real, provable answer.

## Two tracks, deliberately apart

The recording consolidation and the parameter vocabulary are independent, and
keeping them apart is what keeps either reviewable:

| | recording | parameter vocabulary |
|---|---|---|
| files | odelia's `step_record` exposure; plant's `store_trajectory` and four call sites | `tf24_strategy.h`, `patch.h`, `gradient_status.h`, R strings, the ladder helper |
| behaviour | none — a pure refactor | **changes the answer**: eleven new columns, renamed R-visible statuses |
| verification | every number identical, bit for bit | the ladder's declared-zero lists move with it, deliberately |

They meet only inside `census_trait_gradient`, at different lines. Their risk
profiles are opposite, and that is the argument: the recording track's whole claim
is *no number moved*, and that claim is only clean against an unchanged column
set. Land recording first for exactly that reason.

## Increments

Subtraction, then scaffold, then capability. Each lands green with numbers
unmoved.

0. **Subtract.** ✅ `forward_derivative` and its test; the column predicate 4 → 1.
0.5 **The direct term becomes the accumulator's initial value.** ✅ Row 6, and it
   needed none of the rest — found on review, landed first.
1. **Projection, and the declarations behind it.** Row 9's other half: the four
   projections that read no instance become `n_species × static table`;
   `ad_column_count` inlined; `no_column` leaves `Kind` for `optional`. Then rows
   11 and 12, which are larger than "projection" and change behaviour for the
   better: keep the refused input's index so a refusal lands on its column, and
   let the run report slack from the operating point instead of the table
   declaring it. The ladder's declared-zero test is the referee for both.
2. **Scaffold.** `odelia::ode::trajectory<W>`: validated at construction,
   absorbing `state_segments` and `insertions_of`; the widening records its time
   at `scm.h:581`; `recorded_widening` and `ode_step_record` deleted; the five
   loose-array signatures collapsed; plant's 4 unpackings and 4 bridges deleted.
   **And the sweep stops reading times off the solver** (row 10) — the trajectory
   becomes the only source, which retires the length check that keeps the two
   agreeing today.
3. **Capability.** Seeds keyed by step; `extra_splits` becomes the zero-seed case.
4. **Delete Way A.** Measure the lift first. Then route `compute_jacobian`
   through the one engine and remove everything under "What this settles".
5. **The heavyweight recorder.** `history`/`collect`/`get_history_*` — row 5's
   other half. R-facing and breaking; the user's call, not mine.
6. **T4.** The three leaf names, and the macro argument they hold up. Also
   R-facing and breaking.
