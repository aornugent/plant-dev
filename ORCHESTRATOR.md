# Orchestrator

How to run implementation work through subagents in this project. One session acts
as architect, orchestrator and reviewer; packets do the implementation in isolation.

**Read first, in this order:** `AGENTS.md` (session start, style), `METHOD.md` (how
to verify, build and measure — the gate rules are not optional), `NEXTSTEPS.md`
(what to build and in what order). Then `docs/reports/00`–`04` by the section that
owns the claim you are about to cite.

The division of labour exists because an agent cannot assess its own completeness.
What replaces self-assessment is that **every packet's gate is a command whose
output the orchestrator re-runs**.

---

## 1. The orchestrator's four failure modes, and what to do instead

An implementer works inside one file with one claim to defend, and reads it closely
because that is the whole job. The orchestrator holds the design and writes about
code it is not reading at that moment. So the errors are not symmetric, and neither
are the defences. These four are the orchestrator's, and each has a cheap
counter-move.

**The unread document.** Cite the section that *owns* the thing, never the section
that mentions it. Two sections may disagree, and a packet written from the wrong one
fails in a way that looks like an implementation problem.

> BAD — pointing at a document you have not opened.
> `See report 01 §4 for the trajectory record format.`
>
> GOOD — the claim, then where you read it.
> `The trajectory record carries the step size (report 01 §3.2, "each entry holds
> h"). Report 04 §2 says it does not; §3.2 owns the format, and 04 is wrong.`

The second form does the work of reading in advance. It also means a disagreement
you walked past becomes visible to the implementer instead of invisible.

**When two documents disagree, that is the finding and it outranks the task.** Stop
and resolve it against the code. Do not pick the reading that fits the packet.

**The unverified environment.** A packet's base commit, its sibling install, and the
fact that the two compile together are part of its specification. Prove the pairing
builds, or name the incompatibility it will hit and why that is acceptable. `plant`
reaches `odelia` through the *installed* package, so a stale install is not visible
in any diff — certify it per symbol, as `METHOD.md` §4 requires.

**The unpriced gate.** Write the cost in the packet, in seconds, beside the command.
A gate whose cost you did not write down is a gate you did not choose. Section 4 is
how to choose.

**The unguarded edit.** Every packet gets a file allowlist, its own worktree and its
own R library. Section 3.

**And do not tell an agent which obstruction will be largest unless you measured
it.** A guess stated as an expectation is a bias the agent spends evidence to
overturn. State what you know, mark what you are guessing as a guess, and ask for
the ranking back.

> BAD `The hard part will be the untemplated environment.`
>
> GOOD `I have not measured which group is largest. Report the groups by count.`

---

## 2. The packet

A packet is a bounded change whose gate someone who was not there can re-run. If the
gate cannot be written as a command with an expected answer, the packet is not ready.
Every field, every time:

1. **The change in one sentence, plus an explicit file allowlist.** Touching
   anything else is a deviation to report, not initiative.
2. **The gate as a command, its expected answer, and its cost in seconds.**
3. **The environment, proven** — which base, which sibling install, and that they
   build together.
4. **What it may not do:** no baseline regeneration, no adjacent tidying, no new
   files unless named, and **no design choices** — where two readings exist, report
   both and stop.
5. **Required reading by pointer**, being sections you have read yourself.
6. **The build recipe verbatim** from `METHOD.md` §4, including the `rm -f`.
7. **The style rules verbatim**, plus one before-and-after exemplar from the file
   being edited.
8. **Its own worktree, its own R library, its own scratch directory.**
9. **The fingerprint it must reproduce before its first edit** — see §4. Give the
   number; do not make the packet discover it.
10. **Report format:** the diff, each gate's output pasted verbatim, and an explicit
    "what I could not do". Say plainly: *do not report a gate as passing that you
    did not run.*

**A baseline is a property of a commit, a configuration and the script that produced
it.** Quote all three, every time you hand a number to a packet. A number without
its configuration is how one model's arm gets handed to three models.

---

## 3. Isolation

Each packet gets its own worktree, its own R library when it touches `odelia`, and
its own scratch directory. `plant` reaches `odelia` through the installed package, so
two agents installing into one library overwrite each other's headers.

```sh
mkdir -p /home/user/lib-<packet>
export R_LIBS_USER=/home/user/lib-<packet>
Rscript -e 'install.packages("<odelia worktree>", repos = NULL, type = "source")'
```

**Your own verification needs its own worktree too** — a detached checkout at the
commit SHA that nothing else touches. Two concurrent builds in one worktree leave a
half-written `.so`, and **loading one succeeds and returns plausible wrong numbers**.

**Remove a worktree when its packet closes.** A worktree holds its branch checked
out, so a stale one makes `git checkout` of that branch fail elsewhere and pushes
the next agent onto a detached HEAD without saying so.

---

## 4. Spend verification where it discriminates

The costs here span four orders of magnitude, so *which* check runs matters far more
than how many.

| check | cost | what it can establish |
|---|---|---|
| read the diff; `scripts/build/style-sweep.sh` | seconds | a dropped guard, a deduced return type, a comment made false |
| one test file | 1–2 s | the component's own behaviour |
| a build | ~95 s idle, up to 10 min contended | that it compiles at all |
| short-lifetime run | seconds to ~10 s | a fingerprint: did the numbers move |
| full serial suite | ~3 min | nothing regressed |
| production run | ~90 s idle, ~7 min under a wave | a cost factor, a production-state gradient |

Four rules follow.

**Give each packet a fingerprint, not a baseline.** A packet must know its tree is
sound before it edits, but that does not need a production run. Take **one**
production baseline per wave, yourself, in your own worktree, and hand every packet a
short-lifetime number instead — same tree, seconds to reproduce, and it moves for
every change that matters. A packet that cannot reproduce its fingerprint stops. A
packet that reproduces it has earned the right to edit, and has not spent seven
minutes doing so.

**Batch the expensive checks at the wave boundary, one lane at a time.** Production
runs, cost gates and the full suite belong to the integrator, after the merge, on one
tree. Running them per packet multiplies the cost by the packet count *and* makes
each one slower, because concurrent lanes contend. Contention is self-inflicted: with
one packet running, a single process gets essentially a whole core.

**Fan out the writing; take the builds one at a time in dependency order.** Authoring
costs context, not CPU. Building and running are the contended resources. A wave of
three lanes loses to a queue whenever the lanes are not genuinely independent — and
fanning out a dependency chain is worse than serial, because the downstream agent
rebases onto a moving base and its bit-identity gate then measures the rebase.

**Count the builds before starting.** A phase's wall clock is roughly its build count
times one build. To fit a phase in one turn, reduce the count; overlapping does not
help.

**Elapsed time is not progress, and absence of a completion notification is
indistinguishable from work.** Check file mtimes and CPU time against elapsed. Give
any packet that may run long an explicit checkpoint, so a reclaimed container leaves
something behind. And bound a gate's cost when writing the packet: while an
expensive gate runs the agent is unreachable, and a queued correction lands only at
its next tool round.

---

## 5. Gate what the gate can see

Templating at `S = double` generates identical object code. So a value gate on a
type-level refactor is blind to a deduced return type, a swapped like-typed argument,
or a dropped guard — the defects that class of change actually produces. A static
read finds those; a bit-identity run cannot.

- **Write the change in full, review it statically and adversarially, then build
  once.** Keep commits as a structure for reading, not as a schedule of gates.
- **Put the real check where the errors surface.** For scalar templating that is the
  active build, not the `double` suite.
- **Prove a gate command fails when it should.** Break the thing it checks and
  confirm the command notices. This is the cheapest check in this document and it
  subsumes most of §1's advice about gates.

**This economy inverts when the phase moves numbers.** Then a step whose own claim is
bit-identity has earned its run, because it is the only thing separating "I broke the
loop" from "the value moved by the predicted amount" — attributing a large move to
one change requires that everything around it was proven inert. Most of
`NEXTSTEPS.md` is such a phase. What gets batched there is the **re-blessing**, not
the intermediate gates.

---

## 6. Stopping is the product

A stopped packet with a diagnosis is worth more than a finished one that papered over
a contradiction — and the practice only works if that is true in fact and not just in
the packet's wording.

- **Say so when the packet was wrong.** An agent told "your environment was broken
  and it was mine" reports the next problem faster.
- **Ask what the packet cost, and which gates were uneconomic.** The implementer is
  the only one who watched them run.
- **Prefer a resume to a fresh packet.** An agent resumed with its context intact
  keeps everything it learned; a new one pays for that ground again.
- **Do not reward a weakened gate.** When a gate fails, the wanted output is the
  numbers and a stop — not a tolerance that lets it through. Say this in the packet,
  then honour it.

**Stopping inside a single turn cannot mean waiting.** Record the finding with its
evidence, finish every task that is not downstream of it, and say plainly at the end
what was left and why. **A turn that lands five of seven tasks with the other two
diagnosed is a good turn; one that lands seven with a tolerance widened to fit is
not** — and the two are only distinguishable if the gates were written down first.

---

## 7. Review and integrate

`METHOD.md` §7 is the checklist. What is specific to running packets:

- **Re-run every gate in your own session and your own worktree.** A false pass is
  worse than a gate not run.
- **When an agent reports a contradiction, investigate against the code before
  overriding it.** Treat the report as evidence about the plan, not about the agent.
  Overriding one costs a rebuild; being wrong about one costs the wave.
- **Distinguish an agent's harness from its tree.** Comparisons taken with one
  harness on both sides are sound; the absolute numbers may not be.
- **A mechanical sweep over every diff before it lands** —
  `scripts/build/style-sweep.sh <worktree> <base>` — **plus reading every comment
  line you did not write.** The sweep reports candidates, not verdicts, and it cannot
  see a comment the change made false.
- **The cross-model tripwire on every merge, not at phase end.** `METHOD.md` §5.
- **One integration branch per repository.** After each merge, verify every change is
  present by **reading the merged tree** rather than trusting the auto-merge, and
  check the arithmetic: four packets adding 4, 11, 27 and 7 assertions to a 264-pass
  baseline must show 313, and anything else means the merge lost or duplicated
  something.
- **Some work has no packet and it is the integrator's.** Before closing, list the
  documents the change touches and check each against what landed.
- **Re-bless nothing until the owner accepts the shift.** Recording it is the job;
  accepting it is theirs. Leave a moved assertion *failing* through the work and put
  the re-blessing in as one pass at the end.

**Three kinds of failing assertion come out of a value-moving change and only one is
a re-blessing.** Conflating the first two ships a segfault or silently drops a
capability.

| | what it is | what it takes |
|---|---|---|
| a moved baseline | the same assertion, a shifted number | re-bless, with the shift recorded |
| a subject that stopped existing | the assertion can no longer express what it tested | **migrate the test**, and check first whether a capability went with it |
| a design choice | two readings, and the assertion encodes one | leave failing, record both, the owner's |

---

## 8. Where the state lives

| what | where |
|---|---|
| what to build, in order, with its gates | `NEXTSTEPS.md` |
| how to verify, build, measure; the reference numbers; the harnesses | `METHOD.md` |
| the derivations the plan rests on | `docs/reports/00`–`04` |
| re-runnable probes and spike patches | `docs/probes/` |
| what was built, at which commit, and what each number moved | `docs/archive/implementation-notes.md` |
| the plan the build was run against | `docs/archive/build-plan.md` |

The last two are **archived**: every task in that plan is built, and the ledger's job
was to be the one home for numbers nobody is now re-deriving. Read them for
archaeology, cite them by commit and path, and do not design from them.

**Phase 4, which no live document else carries.** Invasion gradients omit the light
knot pullback — the resident pass with one step left out — but `run_mutant` is broken
and cannot be fixed from adjacent work: **nothing in plant or odelia calls
`cache_ode_step`, `cache_RK45_step` or `load_ode_step`**, all three declared and
defined with no caller, which is exactly the two known `test-mutant.R` errors. Then
FF16 and K93 (the templating plus the existing census reduction), two species (two
`Leaf` objects, per-species eta inside the light reduction; every incidence number in
this corpus is single-species), calibration (which reads intermediate trajectory
states as active values, and a `double` trajectory breaks it without a message), and
TF24f.

---

## 9. The wave plan

Written as a dry run, not yet executed. `NEXTSTEPS.md` owns each task; this owns the
order, the lane, and what each wave may spend.

**Lanes are file regions, because that is the only axis along which parallel packets
do not thrash.** Four nearly disjoint sets:

| lane | files | tasks |
|---|---|---|
| L (leaf) | `leaf_model.{h,cpp}`, `models/tf24_strategy.h` | 0b, 1, 2, 3 leaf half, 4, 5 |
| D (demography) | `scm.h`, `species.h`, `patch.h`, `individual.h` | 6, 7, 8, 9, 10 |
| O (odelia) | `ode_solver*.hpp`, `gradient.hpp` | 11 |
| B (boundary) | `RcppR6_classes.yml`, `R/`, `stand_gradient` | 3 plumbing half, the exports |

Lane L is a queue, not a fan-out: tasks 2 to 5 all edit what task 1 creates. Lane L
is therefore the critical path, and lane D holds the correctness work that outranks
it.

### Wave 0 — state and instruments

Done: the develop merge on `p3/wave5` at `d3392ea3`, the odelia merge at `a3bcf58`,
69 stale worktrees removed. Remaining, and none of it needs #590:

1. **The cost harness, lane B.** Export `Patch::block_recording_size` and
   `block_sweeps` to R. Nothing asserts that a block costs what it was measured to
   cost, which is how a factor of 300 sat behind a green suite. **Every later task
   claims a factor; without this harness no packet can prove its own claim.** Build
   this before any task that quotes one.
2. **Task 0b, lane L.** The guard. It decides which leaf states every later gate may
   be seeded at, so it precedes all of them.
3. **The wave fingerprint.** One production baseline, taken by the integrator; a
   short-lifetime number for the packets. Section 4.

### Wave 1 — correctness, lane D, and it outranks every cost task

**Task 15, then 16, then 6, then 7, then 8.** Task 15 first because until the aliasing
is fixed no other seed defect can be measured — a second sweep reads aliased values
whatever else is right, so Task 6's gate would read garbage. Wave 3 may proceed in lane
L concurrently, because the file sets are disjoint.

Task 15's decisive test costs one recompile: reorder `tf24_census` to put `area_stem`
first, and see whether correctness follows row 0 rather than the metric.

### Wave 2 — #590's arrival, lanes D and B

Tasks 9 and 10, then Task 0 for the reference data. Task 10 removes the second leaf
solve, so take Measurement A again after it: every factor in lane L is quoted against
10.64 calls per block, and Task 10 halves that number.

### Wave 3 — the leaf, lane L, strictly serial

Task 3's plumbing first (lane B, and Task 2 cannot be written without it), then Task
1, Task 2, Task 3's leaf half, Task 5, Task 4. **Task 5 precedes Task 4**, not the
order the task numbers imply: see section 10.

### Wave 4 — the rest of the cost work

Task 11 in lane O, then 12 and 13, then 14 if the memory allows.

---

## 10. What a dry run of section 9 found

Walked task by task before execution. These are defects in the plan, not in the code.
Fix the plan first: each one costs more after a packet has been sent.

### The plan reaches fast. It does not reach correct.

The arithmetic for speed closes. For 44 traits the chain is Task 1 (5.3) times Task 10
(2) times Task 11 (3) times Tasks 12 and 13 (1.2) times Task 14 (1.5), with Tasks 4
and 5 inside the leaf, against an Amdahl share that moves from 98.16 percent to about
a third. **Tasks 2 and 3 contribute nothing to this number**: their figures are 1.005
and 1.00 for all 44 traits, and 44 traits is what V4 asks for. Composition has never
been measured, so treat the total as a hypothesis.

Correctness does not close, because **four defects have no task**:

1. **`height_seed` carries no derivative.** `rebind_from` passes `height_0`,
   `area_leaf_0` and `eta_c` as values, so `d(height_0)/d(trait)` is absent from both
   AD paths. Measured as about 3 percent for `lma`. **No instrument in this plan can
   referee a fix**: the forward tangent loses the same term, and a finite difference
   cannot run at production because a relative `lma` step of 2e-7 flips the stand to
   zero. Fixing this needs `odelia::implicit_value` on `height_seed` *and* a new
   referee. Nothing schedules either.
2. **DIAGNOSED. The stop has three causes and Task 6 is none of them.** The seed is
   aliased for every metric after the first, because `census_state_adjoint` builds the
   active twin once and `vector_jacobian_product` calls `tape.clearAll()` on each of its
   three calls, resetting the slot counter under values that outlive it. `leaf_area` is
   right only because it is row 0 of `tf24_census`. Separately, the traits of the field
   build reach no accumulator, which is the whole of `k_I`. Both are now tasks 15 and
   16, and **Task 11 supersedes Task 15**, which moves it from a cost task to the
   correct end-state of a correctness fix. Wave 1 no longer needs a diagnosis packet.
3. **Four trait columns are wrong or absent with no owner.** `beta_R_H` and
   `beta_R_V` have no row at all; `psi_crit` and `root_psi_crit` read zero except when
   pinned, and the pinned gap is unexplained. Task 5 fixes the other four hydraulic
   columns and not these.
4. **V4's own harness is broken.** `scripts/v4-census-gradient.R` and
   `scripts/v4-reference.R` perturb `pars[["lma"]]` directly, which never recomputes
   the derived strategy quantities, and `scripts/v4-reference.rds` belongs to a
   superseded configuration. **A passing V4 needs the harness rewritten through
   `add_strategies`, and no task does that.** Write it in Wave 0, next to the cost
   harness: it is the acceptance test the whole plan is aimed at.

### Ordering defects, each verified against the code

- **Task 2 cannot precede Task 3.** Task 2's condition is written with `par_wanted`,
  which does not exist. `leaf_model.cpp` has `rebuilds_transport` and no notion of a
  parameter being wanted; that notion is what Task 3 builds. Task 2 is two lines only
  after Task 3's plumbing lands.
- **Task 5 must precede Task 4.** `reaches_operating_point` excludes only `psi_crit`,
  `root_psi_crit`, `rho` and `a_bio`, so `b`, `c`, `root_b` and `root_c` are among
  Task 4's eleven parameters. Task 4's gate is the central difference it replaces, and
  Measurement E shows that difference is wrong by 47 to 10 245 times for exactly those
  four. **Four of Task 4's eleven rows would be gated against a poisoned reference.**
- **Task 0b moves the pinned rows, so it must be measured before Task 1.** At the
  `bound_a` pin `psi_stem` equals the collar potential, so the forward guard
  `psi_upstream >= psi_stem` fires and the forward path reports
  `gamma * umol_per_mol_to_Pa`, while `input_adjoints` root-finds. They disagree
  there today. Making them agree changes the pinned rows. Task 1's gate is bitwise
  equality of rows against the previous build, so its baseline must be taken **after**
  Task 0b, and Task 0b's own gate must expect the pinned rows to move.
- **The stop table of section 1 expires when #590 lands.** It was taken at
  `max_patch_lifetime = 2` on the height coordinate. Task 0 says each earlier
  reference number is then wrong. Task 6's gate reads that table, so the stop has to
  be measured again on the new coordinate before Task 6 can be gated.
- **Task 10 invalidates every factor in lane L.** They are all quoted against 10.64
  `input_adjoints` calls per block, and Task 10 removes the second leaf solve. Take
  Measurement A again after Task 10, before quoting a factor to a packet.

### Task 1 was written against a leaf that restores itself, and it does not

**The gate I specified could not pass.** It required the leaf state after one
`output_rows` call to match the state after `1 + n` `input_adjoints` calls. `PPFD_` is
restored by accumulating arithmetic rather than by assignment —
`h = PPFD_*1e-6; PPFD_ += h; PPFD_ -= 2h; PPFD_ += h` — and `fl(fl(fl(P+h)-2h)+h)` is
not `P`. It returns at 900, 1000 and 800 and drifts one unit in the last place at 1500,
1200 and 1e-3. So the old code takes each row at a slightly different `PPFD_`, **its
rows are not the rows of one Jacobian**, and at `PPFD = 1500` forty of 810 entries
disagree to 2.087e-06. The gate now compares against **one** old call, and the task is
recorded as removing a defect and moving its gradient rows.

The general lesson, which is cheap to apply and would have caught this: **when a gate
asserts that state is unchanged, check that the code restores by assignment and not by
arithmetic.** A restore-by-arithmetic is a silent one-way ratchet, and the value that
made it visible, 900, is the one a hand-built harness picks.

Three more from the same dry run, each a trap a reasonable reading falls into:

- **`input_adjoints[i_par0 + k]` is written with `=`, not `+=`.** A row loop that
  hoists the assignment out loses the parameter columns of every row but the last, and
  they read exactly zero — the failure mode this plan's own warning describes.
- **`mu * (R_pm[0] - R_pm[1]) / (2h)` may not be hoisted as a quotient**, because that
  re-associates. Lift the raw pair. This is the one place where a reasonable reading of
  the steps silently fails the steps' own bitwise gate.
- **"Keep the order of the statements" is not satisfiable with "put the branch above
  the row loops".** The instruction has to be "keep the order of the calls that move the
  leaf"; a pure write may move, a perturbing call may not.

And step 8 is confirmed deleted: `bound_partials` takes no seed, so it has nothing to
bundle, and step 7 already reduces it to one call per block. Its own four-parameter loop
and **two further tabulation builds that Measurement A never counted** belong to Tasks 2
and 3.

### Underspecified for a packet

- **Task 4 is a derivation, not an implementation.** Eleven mixed second derivatives
  including the implicit-function term of the `ci` root-find. A packet may not make
  design choices, and a derivation is one. The architect writes the eleven
  expressions; a packet transcribes and gates them.
- **Task 5 named a function that does not exist. RESOLVED, plan updated.**
  `odelia::incomplete_gamma` is in neither repository. It lives on the odelia branch
  `claude/odelia-ad-tape-reverse-496fuf` at `f359830`, an ancestor of neither `master`
  nor `p3/odelia-integration` — built in Phase 1, never landed. The agreement figures
  the task quotes come from that commit's own tests. This is section 11's "price the
  placeholder" pattern applied to the plan that names it: **"designed, built, or named
  as owed" collapses three states, and a reader takes it as available.** When you cite
  a symbol as available, check it is reachable from a landed branch.
- **Task 5's tape was unnecessary. RESOLVED: hand-differentiate.** The design keeps
  `Leaf` at `double`, which is what lets the graft serve the forward type and keeps the
  tangent referee; a tape inside the leaf needed `block_state::tape` threaded from
  `Patch::cohort_block_adjoint` through `Strategy`, and that plumbing was in no step.
  Both derivatives are closed form for one extra accumulator: `dgamma/dx` is the
  integrand `x^(a-1) e^-x`, and `dgamma/da` is `log(x) * gamma` plus the same series
  with `-term_n * sum of 1/(a+k)`. `b` and `root_b` need only the first, so two of the
  four wrong columns need no series derivative at all.
- **Task 5's scope is unknown until `psi_from_transpiration` is settled.** The task
  says to check whether the derivative path reads it and not to assume. That makes it
  two packets: an investigation, then an implementation sized by its answer.
- **Task 3's masked NaN was in the wrong place. RESOLVED: mark the column.** A row is
  read by nothing but the two `graft` calls, so a marker there is invisible to the
  consumer that matters, and compaction cannot protect against the NaN actually feared,
  which lives in state columns that are never masked. The marker now goes on the output
  column in `clear_trait_adjoint`, the rows stay clean, and `graft` does not change.
- **A branch kink already makes both AD paths NaN, and this is a live defect nothing
  records.** `layer_flux_partials` returns with every entry NaN at an equal-potential,
  gravity-balance or near-zero-collar condition, no caller tests for it, and
  `partial * (x - to_passive(x))` puts `NaN * 0.0` into the **value** of `leaf_profit_`.
  The plain `double` run is safe, because the graft is under
  `if constexpr (!std::is_same_v<S, double>)`; the tangent and the adjoint are not, so
  one kink NaNs the gradient and its referee together. Decide what a row holds at a kink
  before Task 1 freezes its bit patterns.
- **Two counts in the plan did not reproduce.** 13 of the 15 leaf parameters are
  registered, not 11, and nine of those also reach the operating point; "4 residual
  pairs" is 4 evaluations. So the registration list alone removes 2 of 15, and nearly all
  of Task 3's value comes from the requested subset — which the task's own WARNING, read
  literally, forbade.
- **`Patch::cohort_block_adjoint` never resets `block_workspace`.** A mask set after the
  first block never reaches the leaf, and two `stand_gradient` calls with different trait
  sets silently reuse the first mask.
- **Task 3 crosses the R boundary and no step mentions the generated code.** Making
  the trait set reach C++ changes `inst/RcppR6_classes.yml` and needs
  `make RcppR6 && make attributes`.
- **Task 9 has no gate.** It deletes the weight-derivative term. Deleting a term moves
  numbers, so it needs the tangent of Task 0 and an explicit expectation.
- **Task 1 step 8 belongs to Task 3.** `bound_partials` has no seed dependence, so
  there is nothing in it to bundle; what it needs is the mask. As written the step
  forces the packet to guess which change is meant.

### What stays dead, and should be said so

Task 2's guard is unreachable after Task 5 Stage A, because nothing calls
`build_cumulative_vulnerability_integral` from the reverse path any more. Land Task 2
as insurance, and label it as insurance Task 5 deletes. Task 1 keeps
`input_adjoints` as a contraction over the rows; after Task 1 its only caller is the
gate. Keep it for that and say so, or it reads as a live path.
