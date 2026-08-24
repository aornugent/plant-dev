# The recording, and the sweep over it

One of two tracks. This one is a **refactor whose claim is that no number moves**;
`gradient-columns.md` deliberately changes the answer. They meet only inside
`census_trait_gradient`, at different lines, and a bit-for-bit claim is only clean
against an unchanged column set — so this track lands first.

## Triage: 3 — odelia is published and `Solver`'s accessors are R-visible

## The rule

Two refusals sit under this surface and neither is a preference. **Do not tape the
leaf's solve** — recording a root-find differentiates the solver's iterations, not
the model. **Do not tape the whole trajectory** — it does not fit. Together they
force record-and-replay, and a replayed model asks one question at every seam:

> **What did the run know here, and where is it written down?**

Every duplication below is the same answer: a fact the run knew, dropped, and
reconstructed downstream. The rule is **record the fact where it is known, project
it where it is needed, never re-derive it.**

## Requirements ledger

**R1 — one representation of a recorded trajectory.** ✅ landed. It had six
spellings; see *Increments*.

**R2 — the sweep reads one source for times and sizes.** ✅ landed.

**R3 — the model's insertions are not odelia's vocabulary.** `Widening` is a
template parameter at eleven sites carrying `std::vector<std::size_t>` — plant's
payload type, in odelia's containers, which odelia never reads.

**R4 — the partition is checked once and cannot be skipped.**

**R5 — no number moves.** plant 3283/0/0/13 and 679/0/0/5, phylloptim 2421 checks
+ 223 golden + 1455/0/0/1, odelia 407/0/0/3, and the R-free standalone guard.

**R6 — quantities.** 117 recorded steps. `ode_size` ≈ 5 × cohorts × species, so a
kept trajectory is hundreds of KB. 152 `advance_*` call sites, so no per-call
forward-API change. A rebind happens **once per recording** — about 117 times per
gradient.

**Scarce resource.** Not CPU (`row_batch` already collapsed the per-metric cost)
and not memory (R6). It is **places where two spellings of one fact can disagree
while both compile** — the class every defect in this campaign belonged to, each
producing a plausible finite number rather than an error.

## The floor

Fix only the disagreement paths and leave the shapes alone. Pays R2. Fails R1, R3,
R4 — the projection chain survives entire and the partition check stays both
re-run and skippable. Beaten, but it remains the fallback if the candidates below
are judged too invasive.

## Candidates

**A — move 6, Pólya. One representation of the record.** Commitment: the record
the solver kept is the record every consumer reads. Pays R1, R2, R4. **Won, and
it was a deletion rather than an addition** — see below.

**B — move 3, move the boundary. The recording is an object the caller owns.**
`record_into(&rec)` replaces `set_keep_states(bool)`, so the flag becomes the
object's presence and `keeps_states()` stops being a round trip. One setter
changes, not 152 call sites. Pays R1–R4 and deletes a flag that can disagree with
its own data. **Held for a later increment.**

**C — move 4, storage for compute. Store no states; replay for them.** The classic
adjoint-checkpointing design. **Eliminated on R6**: it spends the resource that is
scarce (a replay is a model evaluation) to save the one that is not. Priced here so
its absence is a decision, and it is the right design the moment R6's memory line
changes.

**A was already built.** `SolverInternal` held `std::vector<step_record>` with
`{time, step_size, state}` and its accessor comment stated the invariant this
design was about to invent a type for: *"a caller cannot pair one run's state with
another run's size."* Three projections then took it apart, plant re-bundled an
identical struct while re-checking a pairing that was never broken, and the sweep
took it apart again. So the winning move was **stop projecting**, and the type
that survives is a validated view that owns nothing.

## The commitment

**A gradient is a seeded recording swept once.**

Kept true by structure:

- `step_record` derives from `recorded_step` — a recording row *is* a schedule row
  plus its state — so the schedule is that record sliced to its base and cannot be
  a second container.
- the record is handed back whole and refused where the run kept no states, so a
  row a sweep cannot use is not a row a caller can be given.
- the sweep reads that record and nothing else for its times and sizes.
- the direct term is the parameter accumulator's **initial value**, so the total
  derivative is the arithmetic rather than a correction to it.

## Kill question

*The assumption whose falsity makes this unnecessary:* that every consumer of a
recording wants the same triple.

False as stated — the R boundary wants times as bare doubles. Narrowed to **every
*sweep* consumer wants the triple**, it holds exactly: all four plant call sites
unpacked precisely `(states, times)`. So `times()` and `step_sizes()` survive as
*boundary projections*, named as such. **Survives, narrowed.**

## Insertions: what a widening actually is

`WidensState`'s own comment concedes the point: *"A System satisfying this asserts
its insertions are scheduled, not triggered."* Node introductions are scheduled and
the step schedule is fixed after an adaptive solve, so an insertion is not a
decision the run made — it is where one fixed schedule lands on another. The code
nonetheless records the payload and the time beside the step index, in a container
of its own, and reconstructs the model's birth dates from it.

**Nothing about it needs recording.** Two facts:

*The state only ever grows during a run.* `remove_newest_node()` is reachable only
from reconciliation — `set_recorded_state`'s shrink loop and the tangent path —
never from the forward run. So **every width increase in the record is an
insertion**, and odelia reads the boundaries off widths it already holds.

The check that appears to be lost is not the one that matters. `state_segments`'
comment is right that inferring boundaries from widths cannot fail its own test —
but the substantive guard is `be_at_step`'s *"reconciled to N wide at step k
against M recorded there"*, which compares the model's reconciliation against the
record **independently of how boundaries were found**. That guard is why
`be_at_step` stays: under this design it stops computing anything and becomes the
named cross-check, which is the one thing there that cannot be derived.

*The payload is configuration, not a record.* `Parameters` carries
`node_schedule_times` and `node_schedule` is built from it. So the plan is stable
input, and `set_recorded_state` was handed a list to replay only because nobody
noticed the plan was still in scope.

So `SCM::widenings` is **deleted rather than moved**, `recorded_widening`,
`recorded_insertion` and `insertions_of` go with it, `Widening` leaves all eleven
sites, and odelia's concept reduces to two hooks with no vocabulary of its own:
the map to transpose, and reconcile-to-a-recorded-step.

### What reconciliation is, and why it is not test scaffolding

**The ODE state vector does not determine the patch.** Outside it are three numbers
per node and the structure the vector is loaded into — how many nodes each species
has. So a pass that re-runs the model from a recorded state must rebuild the
structure and the birth bookkeeping, then load the state. That is reconciliation,
and it is load-bearing on the shipped path: a sweep exists only because the model
can be put back where the run was.

It is **needed once per segment, not once per step**. `step_adjoint` lifts the
System and takes the state as an argument, reading the System only for its
structure; within a segment no nodes are added, so the structure is constant.

### The three stamps are a memo, not information

`push_nodes` says it outright: *"All three are functions of the time it is
introduced at, which is what lets a record hold only the time."* So they cache two
pure functions of the birth date rather than carrying anything independent:

| stamp | is | consumed by |
|---|---|---|
| `node_introduction_time` | the birth date | structure and both derivations below |
| `patch_density_at_birth` | `disturbance->density(birth)` | `weighted_fecundity` — a **census reduction**, not a rate |
| `pr_patch_survival_at_birth` | `disturbance->pr_survival(birth)` | the fecundity **rate**, as the denominator of `pr_patch_survival / pr_patch_survival_at_birth` |

The two consumers differ in a way that matters. Patch density reaches only a
lifetime-fitness reduction, so the ODE never sees it. Survival-at-birth is in a
rate, so it is on the taped path — as a constant denominator, since both stamps are
`double`.

Neither needs restricting to a no-disturbance regime, and neither needs recording.
The birth date is `schedule()[step].time`, `Patch` already holds the regime as
`survival_weighting`, and both values are recomputed from the date. **The stamps
are a per-node memo of configuration, which is not a record of the run.**

**And `S_D` is not the establishment probability.** It is survival during
dispersal, and it appears in exactly one place — `weighted_fecundity =
offspring_produced_survival_weighted × patch_density_at_birth × S_D` — a census
reduction, which is consistent with its `no_column` declaration. Establishment is a
separate strategy method whose value enters the inflow boundary
(`n_b = birth_rate × pr_estab / g`) and therefore **is** ODE state and **is**
differentiated. Three distinct quantities that read alike: `pr_estab` in the
boundary, `S_D` in the reduction, `pr_patch_survival_at_birth` in the rate.

### So reconciliation is not a concept

Read the four-argument loader end to end and it is exactly two steps: **become the
shape these birth times imply, then load.** Shrink or grow each species to
`base + when[i].size()`, stamp what it pushed, refresh the field if anything
moved, check the incoming length against `ode_size()`, and delegate to the
two-argument loader.

And the shape is derivable from the plan and the time. So the operation is: *given
a state vector and a time, produce a correctly-shaped patch holding it* — which is
what `set_ode_state` is supposed to mean.

**It is a separate operation today only because `set_ode_state` cannot resize.** It
loads into whatever node counts the species currently have, so something else has
to establish those counts first, and that something has to be *told* them — which
is the insertion list, threaded from plant through odelia and back.

Let the loader derive its shape and the two collapse — but **on the recorded
loader, not the plain one**, and the reason is worth having.

Time alone does not determine the shape. At an introduction time there are *two*
shapes: before the insertion and after it. The forward run is *after* — it calls
`introduce_nodes` on arriving at `t_intro` — while a recorded step at `t_intro` is
*before*, since the insertion follows that step. A single resizing loader keyed on
time would therefore remove, during the run, the node the run had just introduced.

Split by caller and the ambiguity does not arise:

- **the forward run** loads into the shape it already built, so
  `set_ode_state(y, t)` keeps its meaning and pays nothing;
- **a replay or a sweep** does not know the shape, so
  `set_recorded_state(y, t)` derives it: `base_i + count(plan[i] < t)`, strictly
  below, which is exactly the rule the four-argument loader applies through
  `after_step < step`.

So the two-argument `set_recorded_state` — **which already exists** — gains the
shape derivation, and the four-argument overload goes with the insertion list it
was handed. `WidensState` loses its reconcile member either way, and the plan
lookup lands once per segment instead of once per stage.

`WidensState` is then **one hook**: the insertion map, because a Jacobian needs a
function of the narrower state and no loader provides that. Which is plant's
`introduce_nodes` written as a map — the fold, arrived at from the other side.

Two things to keep rather than lose:

- **the width check.** With a resizing loader, `y.size() == ode_size()` is what
  says the plan and the recorded state agree, and `be_at_step`'s is the independent
  version of it. Both are the guard that licenses detecting boundaries from widths.
- **`compute_boundary_nodes`.** It is the two-argument loader's only addition over
  `set_ode_state`, and it is a different concern entirely: the inflow condition's
  second evaluation. It got bundled under a name about recording that it has
  nothing to do with, and should be named for the boundary.

**The one real complication.** A resizing loader has to know its target shape, and
the iterator form `set_ode_state(It it, double time)` carries no length — so it
cannot resize on mismatch and would have to consult the plan on every call, once
per stage. Cheap, since the plan is a handful of times, but not free where it is
now zero. The alternative is a sized loader taking a span, which is worth wanting
anyway: an iterator with no length is exactly the shape that lets a width mismatch
through in silence.

### What that leaves derivable

Everything reconciliation rebuilds is derivable from the introduction plan plus the
recorded time:

- **structure** — how many nodes species *i* has: the plan entries for *i* with
  time strictly below this step's. Exact rather than approximate, because the run
  steps *to* an introduction time, so a boundary step's time equals a plan time bit
  for bit and everything else falls unambiguously.
- **birth dates** — the plan's times themselves.
- **the two stamps** — recomputed from each date through `survival_weighting`.

Which retires the four-argument loader in favour of `set_recorded_state(y, time)`,
the two-argument form that already exists, and with it the insertion list that was
being threaded from plant through odelia and back to plant.

### Patch does not need Parameters

`Patch` holds its own `Parameters`, a second copy beside `SCM`'s, and uses it for
three things: seeding at construction, two fields during reconciliation
(`n_initial_cohorts` as the base offset, `initial_state` for the seeded flag), and
a list of fields copied on `rebind_from`.

**Seven of those fields it never reads** — `ode_times`, `ode_step_sizes`,
`node_schedule_times`, `node_schedule_times_default`, `max_patch_lifetime`,
`n_patches`, `patch_type` — yet every rebind copies them, including two vectors
holding the whole trajectory. At one rebind per recording that is about 117 copies
of the trajectory's times and sizes per gradient, into an object that never looks
at them.

So the fix is subtraction, not synchronisation: **narrow what `Patch` keeps to
what it uses.** Then `Parameters` exists once, on `SCM`; the stale-plan hazard
disappears rather than needing three write sites kept in step; and the rebind stops
carrying a record of the run through an object that has no use for one.

The same three write sites expose a second conflation: `parameters.ode_times` and
`parameters.ode_step_sizes` are written *from the finished run*, with the comment
*"Leave Parameters self-describing"*. `Parameters` is configuration **and** a
record of the last run, and its schedule is a third spelling beside
`solver.schedule()`.

### Retiring the concept

odelia has a settled discipline for these, and reading it decides the question.

| kind of requirement | how odelia expresses it | examples |
|---|---|---|
| optional, and odelia **branches** | a concept, used with `if constexpr` | `HasOdeTime` (*"a System that does not is time homogeneous"*), `RecordsChoices`, `ChecksState` |
| a **refusal** | a concept inside a `static_assert`, **with a message** | `Rebindable` — *"a recording is taken on the System at the adjoint scalar; this System has no rebind_from()"* |
| **mandatory** | nothing at all | `ode_size`, `ode_state`, `set_ode_state`, `ode_rates` — and `derivs` is an unconstrained free function template |

`WidensState` is none of the three. It gates four functions with a bare `requires`
that produces no message, for a capability that is not optional — those functions
are meaningless without it — and is not a refusal anyone reads.

So **it should not exist.** The one remaining hook is a mandatory member of any
System the sweep is asked to walk, exactly like `ode_size()`, and the sweep already
calls `ode_size()`, `ode_state()` and `set_recorded_state()` as direct members with
no concept between. The hook joins them:

    system.inserted_state(step, x, y);      // the state an insertion produced

Plant implements it as a two-line forward to its own introduction-as-a-map, which
is the `extrinsic_drivers` pattern: odelia names what it needs, plant keeps its own
verb, and the adapter is one line and says so.

If a message is wanted for a System that lacks it, the `Rebindable` form is the
one to copy — and `state_and_parameter_adjoints` already carries such an assert at
exactly the site the boundary transpose goes through, so there may be nothing to
add.

**Not a Jacobian utility.** The utility already exists:
`state_and_parameter_adjoints`. At a boundary the sweep spends five lines on it,
and naming those five would be a wrapper with one caller. And plant supplying the
Jacobian itself is worse than taping the map — an insertion's Jacobian is identity
on the existing entries plus dense rows for the newborn, whose initial conditions
reach the whole narrow state through the light field and the birth rate. Writing
that by hand is the thing this design exists to avoid.

### Naming

`widening` is opaque. The layering says which word belongs where: **odelia names
what happens to the vector; plant names what happened in the world.**

| | now | proposed |
|---|---|---|
| odelia, the event | `widening` | `insertion` — entries are inserted into a vector, and `recorded_insertion` already says so |
| odelia, the map | `widened_state` | `inserted_state(step, x, out)` |
| odelia, the concept | `WidensState` | `InsertsState` |
| plant, SCM | `widenings` | deleted; plant's own verbs (`introduce_nodes`, `node_schedule`) are already right |

Not `grow`: it names the vector's size, which is the consequence. Not
`add_particle`: the instinct is right that the thing added is an individual, but
"particle" imports a physical model an ODE library has no business asserting.

## What this settles

- `ode_step_record`, `recorded_times()`, the re-bundle, four state unpackings and
  two schedule conversions: gone.
- `recorded_widening`, `recorded_insertion`, `insertions_of`, `Widening` at eleven
  sites, and `SCM::widenings`: gone.
- Two accessors that existed for one example and one test: gone.
- The stale-plan hazard between two `Parameters`: dissolved, not synchronised.

## What this makes hard

A caller wanting only times uses a boundary projection or holds a record it does
not need. Coped with by keeping `times()`/`step_sizes()` for R, which takes vectors
of doubles anyway.

And a second recording is not solved. `SCM::record_trajectory` drives both the
solver's states and `patch.recording` — the strategy's per-stage choices, read at
`patch.h:1152`. They must agree or a replay re-derives a discretisation the run
never took, with every number finite. Today that invariant is two adjacent
assignments and nothing else. The states' half becomes an object; the choices' half
lives inside the strategy per node per stage, so the honest scope is **both driven
from one call**, not both becoming one object.

## Kill condition

R6's memory line changes — very long runs, or cohort counts that make a kept
trajectory large. That hands off to C, checkpoint-and-replay, and nothing else
moves.

## Increments

1. ✅ **The record, handed back whole.** `step_record` derives from `recorded_step`;
   `Solver::recording()` returns it, refusing where no states were kept. Five
   signatures each take one thing. plant's four gradient entry points went from 131
   lines to 41. `odelia@a938d30`, `plant@fcf158ff`.
2. ✅ **Residue swept.** `has_recording()` and `recorded_state(k)` deleted; the
   example states its own precondition; a `recording`/`trajectory` name collision
   fixed. `odelia@cc7e74d`, `plant@adea9914`.
3. ✅ **`Solver::schedule()`.** Four hand-built schedule loops in odelia's own
   tests collapsed to one line each. `odelia@762296b`.
4. ✅ **Stop rebinding a record of the run.** Three of the nine Parameters fields
   the rebind copied are read by nothing on the patch — `ode_times`,
   `ode_step_sizes` (a record of the run, read only by `make_node_schedule`) and
   `n_patches`. The other six are load-bearing: `patch_type` and
   `max_patch_lifetime` are read by `validate()`, which rebuilds the disturbance
   regime, so dropping them moves `pr_patch_survival` and the fecundity rates with
   nothing raised. `plant@c6c65955`.
5. ✅ **The recorded loader derives its shape**, and the insertion vocabulary is
   gone. `reshape_to(time)` works out what a recorded step implies from the
   schedule; `SCM::widenings`, the four-argument overload, `recorded_widening`,
   `recorded_insertion`, `insertions_of` and the `Widening` parameter at every site
   go with it. odelia reads boundaries off recorded widths, refusing a width that
   shrinks — the one check an inferred boundary can still fail. `WidensState` is
   deleted; its two members are mandatory for a System a sweep walks, so they are
   called directly like `ode_size()`. odelia −168/+82, plant −91/+109.
   `odelia@55fdc51`, `plant@d1195908`. Every number unmoved.
6. ✅ **The schedule written out from one source.** `parameters.ode_times` and
   `ode_step_sizes` are an *input* — a schedule a caller can ask the solver to
   stop at — and nothing in the design reads them as the run's record. The
   write-back stays, being documented and tested, but reads `solver.schedule()`
   rather than pairing a time with its size a second time.
7. ✅ **The two loaders named apart.** `set_recorded_state` had two overloads
   doing different things; the one that loads into the shape it finds and settles
   the inflow condition is `set_state_and_boundary`. `plant@dca388e5`.
8. ✅ **The patch's schedule refreshed where a run begins.** A reconciliation reads
   the plan to work out a step's shape and reads the patch's copy, while
   `r_set_node_schedule` updates the SCM's only — latent, and wrong with nothing
   raised. `plant@f514f043`.
9. **Resolve both schedules up front, and key the shape by step.** For a reverse
   pass, *both* schedules are known before taping starts: the introduction
   schedule is configuration, and the ODE schedule is fixed once the adaptive run
   has resolved it. So the step-to-shape mapping is fully determined before the
   sweep begins, and belongs resolved once at its start rather than worked out per
   call.

   `state_segments(rec)` already *is* that resolution, computed once by the driver.
   What is missing is that the patch is asked by **time** rather than by ordinal:

       be_at_step(system, rec, step, applied)   // applied, off the segments
       inserted_state(j, x, y)                  // the j-th introduction

   No new state anywhere — the table is the segments, already built. The reason to
   do it is **not** speed: the plan is bounded by the recording, since every
   scheduled introduction lands on a recorded step, so the scans are over about a
   hundred entries and cost nothing. It is that a step index is exact by
   construction where a time comparison has to be argued for, and it takes a
   question out of the reader's way.

   ⚠️ **And a warning about how not to measure this.** Two performance diagnoses
   were made here by inspection and both were wrong: a "quadratic in the schedule"
   that arithmetic refutes, and an "18× regression" that was forty stray R
   processes and a concurrently running suite. The runner launches every file with
   `&` and waits, so a second suite halves the cores; and wall time is bounded by
   the slowest single file, which makes the ladder's documented 17 s a figure for
   the 13 files it had rather than the 18 it has. Measured clean: one file 10 s,
   the whole ladder 61 s.
10. **Declined: `record_into()` replacing `set_keep_states(bool)`.** One bool,
   one setter, one reader, and `recording()` refuses when it is false — so the
   flag and the data cannot silently disagree. Every alternative is bigger: a
   caller-owned vector changes the forward API across 152 sites, keeping states
   always regresses memory on long non-gradient runs, and a variant of two row
   types is more machinery.
11. **`history`/`collect`/`get_history_*`** — the `vector<System>` recorder that
   `least_squares` copies whole Systems out of to read state vectors. R-facing and
   breaking; not mine to land.
