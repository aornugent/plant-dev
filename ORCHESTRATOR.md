# Orchestrator

How a phase of this build is run: one session acting as architect, orchestrator and reviewer over
subagents that do the implementation in isolation. Written to be handed to a fresh session.

The division exists because an agent cannot assess its own completeness. What replaces
self-assessment is that **every packet's gate is a command whose output the orchestrator re-runs**.
Two phases of evidence now support the division and locate the risk in the same place: the agents
corrected the architect eleven times across Phase 0 and Phase 1 and stopped on five real
contradictions, while **every expensive failure in both phases was the orchestrator's** — an
unguarded edit, an unread document, an unpriced gate, an unverified environment. So the discipline
below applies hardest to the orchestrator's own hands, and §0 is where it bites.

**The organising fact, learned the expensive way.** Every costly failure in Phase 1 traced back to a
cheap check that was skipped. Reading one section of the plan — five minutes — would have saved three
attempts at one task and roughly four hours of compute. Confirming a packet's two repositories
compile together — thirty seconds — would have saved three dead first cycles. Doing the arithmetic on
one gate — one minute — would have saved an hour of full-CPU work on a gate that was already
retracted. **Slow is smooth and smooth is fast: the pre-flight in §0 is the cheapest hour in the
phase.**

---

## 0. Before you send anything

Six checks. None takes more than a few minutes. Each one, skipped, cost this project real time.

**1. Read the section that owns the thing, not the section that mentions it.** `build-plan.md` §2.8
is the reverse pass's control flow; §2.9 is what is stored. They disagreed about whether a trajectory
record carries the step size — §2.8's pseudocode records `(t, h, y)`, §2.9's prose says "the ODE step
times" and its storage table lists state alone. Two packets were written from §2.9 and both failed.
**When two sections of the plan disagree, that is the finding, and it outranks the task.** Write it
down before you write the packet.

**2. Never cite a document in a packet you have not read.** Phase 1 pointed packets at §2.8 and §2.9
by line number without the orchestrator having read either. The agents read them and were better
informed than the person directing them, which is a bad way to run a review.

**3. Prove the packet's environment compiles.** A plant base paired with the wrong odelia bit three
times: a base without `value_type` against the constrained range helpers (56 errors); a base
predating the plumbing sweep against an odelia with the typedefs deleted (68 errors); and a plumbing
baseline that had no build in which base plant and the new helpers could coexist at all. Build the
pairing yourself, or state in the packet which incompatibility it will hit and why that is
acceptable. **A packet's environment is part of its specification.**

**4. Cost every gate, and write the cost in the packet.** `refine_schedule = TRUE` is up to
`control.schedule_nsteps = 20` production runs, and a packet asked for it before *and* after — an
hour-plus gate, retracted after 50 minutes of full CPU. `schedule_nsteps = 2` exercised the same
defect *better*, because the fault appears on the second run and two steps attribute it to one
contaminated run rather than nineteen compounding ones. **Cheaper and sharper were the same choice.**

**5. Check the gate is satisfiable.** Phase 1's active-build packet was told the active value must
equal the `double` value *to the last bit*. It cannot: on `double` the canopy takes a multiplication
chain and on an active scalar `std::pow`, and this repository had already measured those disagreeing
by 2 ulp at the default exponent. The contradiction went unnoticed only because compile errors
stopped the comparison from running. **Ask what would make this gate impossible, not just what would
make it fail.**

**6. Ask what would make the gate pass vacuously.** The trajectory store depends on a concept being
satisfied by four member names: unsatisfied, the recording hook never fires and every downstream
assertion passes on an empty store. **A gate that cannot distinguish "correct" from "absent" is not
a gate.** Look for the version of each gate that passes when nothing happened.

An earlier version of this section credited that gate to an agent. **The audit found it was never in
the tree** — the notes recorded a claim, not a commit, and it took a `grep` to notice. So the rule
has a second half: a gate you recorded is a gate you should be able to point at. §7's "re-run every
gate" covers the ones you ran; this covers the ones you were told about.

---

## 1. Rebuild context before designing anything

In this order, and in full rather than by grep:

1. `AGENTS.md` here, `plant/agents.md` (including §13), `odelia/AGENTS.md` — session start, build
   recipe, style. **The two style guides disagree about issue references** — the workspace forbids
   issue tags, odelia permits a stable anchor like `#472` — and nobody has decided which governs
   plant. Know that before you enforce either.
2. `docs/build-plan.md`. §2.8 and §2.9 are the design of the reverse pass and of what is stored, and
   they are the two most consequential sections in the file. Read them before any task that touches
   the trajectory, the aux transfer, or the stage rebuild.
3. `docs/tf24-correctness.md` — the prerequisites and what has landed, at which commit.
4. `docs/implementation-notes.md` — the evidence, the pinned build, the standing lessons. Phase 1's
   entries are long because the failures were informative; read the "what the plan did not predict"
   subsections first.
5. `docs/implementation-notes.md`'s Phase 1 audit section — what the merged tree got wrong, what
   was fixed, and the five spikes that killed four design ideas. The close review it came from is
   archived; this is the live account.
6. `docs/reports/00`–`04`, `07`. **Read them twice: once for the design, and again at review time
   against the code.** Report 01 §3 names the carried boundary density that sank three attempts at
   the trajectory store; it was read at session start, and its relevance only became visible when a
   measurement demanded an explanation. A report read once is orientation; a report read against a
   diff is a review tool.

**Items 1–5 are decisions and are read in full; item 6 is evidence and is read by the section.**
Two sessions ran out of context reading the corpus and had none left to execute with, so the
economy has to be stated. The plan and the notes are what a packet can contradict, so the
orchestrator holds all of them. The reports are ~4 900 lines of measurement, and §0.2's bar — never
cite what you have not read — is met by **the section that owns the claim**, which is also what
§0.1 asks for. So cite `report 03 §1b` having read §1b, and let the packet read the rest of report
03 for the mechanism. **Where a phase is to run in one turn, this is the difference between
possible and not.**

Then establish ground truth rather than assuming it, because the tree moves between sessions:

- `git log`, `git status`, and **the submodule pointers**, in both `plant` and `odelia`.
- Confirm the pinned build took: a value gate that does not name its flags measures the compiler.
- **Re-measure the reference forward run yourself**, in a worktree nothing else touches. It is one
  build and one run, and it is the number every bit-identity gate in the phase is written against.

## 2. The packet

A packet is a bounded change whose gate someone who was not there can re-run. If the gate cannot be
written as a command with an expected answer, the packet is not ready to send. Every field, every
time:

1. **The change in one sentence, plus an explicit file allowlist.** Touching anything else is a
   deviation to report, not initiative.
2. **The gate as a command, with the expected form of the answer, and its cost.** Not "verify it
   works", and not a gate whose price you have not computed (§0.4).
3. **The environment, proven** (§0.3): which base, which sibling install, and that they build.
4. **What it may not do:** no baseline regeneration, no adjacent tidying, no new files unless named,
   and no design choices — where two readings exist, report both and stop.
5. **Required reading by pointer** — the task's own section and the one report section carrying the
   mechanism. Sections you have read (§0.2).
6. **The build recipe verbatim**, including `rm -f src/*.o src/*.so` before every build.
7. **The style rules verbatim**, plus one before-and-after exemplar from the file being edited.
8. **Its own worktree, its own R library, its own scratch directory** (§5).
9. **Its own baseline first.** Take the base tree's reference number in the packet's own worktree
   before the first edit, and stop if it does not reproduce.
10. **Report format:** the diff, each gate's output pasted verbatim, and an explicit "what I could not
    do". Stated plainly: *do not report a gate as passing that you did not run.*
11. **Work economy** (§6). A packet that rebuilds when it could compile one translation unit will
    spend its budget on the wrong thing.

**Do not tell an agent which obstruction will be largest unless you have measured it.** Phase 1's
active-build packet was told to expect the untemplated environment to be its biggest problem. It was
not — the environment is one funnel, and the largest group was `std::`-qualified math on an active
argument, which has nothing to do with it. An architect's guess, stated as an expectation, is a bias
the agent then spends evidence to overturn.

## 3. Gate what the gate can see

The most useful thing Phase 1 learned about verification.

**Six bit-identity gates on a type-level refactor found nothing, and a grep found three real
defects.** Templating at `S = double` is expected to generate identical object code, so a
bit-identity gate at `S = double` is nearly blind to the hazards that actually matter: a deduced
return type, a swapped like-typed argument, a missing guard. None of them moves a number until an
active scalar arrives. What did find things was reading — a grep for deduced return types found
**three lambdas declared `-> double` that would have silently converted an active value to a passive
one**, which no `double` build could ever see.

So:

- **Write the change in full, review it statically and adversarially, then build once.** Keep commits
  as a structure for *reading* — one idea each — not as a schedule of gates.
- **Reserve per-step numerical gates for steps that can actually move a number.** A refactor whose
  whole claim is "identical object code" is tested exactly as well by one gate at the end. If that
  one fails, bisect *then* — paying the skipped builds only in the case where something really moved.
- **Put the real check where the errors surface.** For scalar templating that is the active build,
  not the `double` suite.
- **A gate command must be proven to fail when it should.** A bare `testthat::test_file()` in odelia
  attaches no package namespace: depending on the file it reports spurious errors, or `FAIL 0 | PASS
  0` at **exit status 0**, which is a false pass. Three packets hit it independently. The
  namespace-bearing form is `testthat::test_dir(dir, package = "odelia", load_package = "installed")`.
  Before shipping a gate command, break the thing it checks and confirm the command notices.

**This section's economy inverts when the phase moves numbers, and Phase 2 does.** Phase 1's gates
were blind *because* the phase was bit-identical by construction — templating at `S = double`
generates the same object code, so no value gate could see the hazards, and reading found what six
gates could not. Phase 2 is the opposite: every task changes a forward number, and the plan's step
decompositions exist precisely so that a bit-identity gate discriminates. P2.1 step (1) is
bit-identical and step (2) is deliberately not; P2.4 step (2) is bit-identical and step (3) is where
the value moves. **Skipping the bit-identical intermediate throws away the attribution the
decomposition was bought for** — it is the only thing separating "I broke the loop" from "the value
moved by the predicted amount". So in Phase 2 what gets batched is the **re-blessing**, and a step
whose own claim is bit-identity has earned its run.

## 4. Sequence and fan-out, decided by dependency

Fan out what is independent; sequence what is not. Fanning out a dependency chain thrashes: the
downstream agent rebases onto a moving base and its bit-identity gate measures the rebase.

**Fan-out multiplies per-packet cost, and a wave's wall clock is not the sum of its packets' isolated
costs.** A production lifetime run is about 90 s on an idle box and about **7 minutes** under a wave
of builds — roughly 5×. Every gate in Phase 1 was costed against the 90 s figure, so a gate stated as
"three minutes" ran twenty. Cost gates for the contended case.

**A packet whose sibling is mid-change should be told which API is moving.** Two Phase 1 packets
touched overlapping odelia surface; naming the accessor being redefined (`recorded_steps()`) was
cheaper than serialising them.

**Write in parallel; build serially.** These are separable and Phase 1 conflated them. Authoring is
free to fan out — it costs context, not CPU, and §3 already says to write a change in full before
building it. Building and running are the contended resources, and the 5× above means three
concurrent lanes of builds make every gate in every lane five times slower, so a wave *loses* to a
queue whenever the lanes are not genuinely independent. **Fan out the writing, then take the builds
one at a time in dependency order.** The corollary is that a phase's wall clock is roughly its build
count times one build, and the way to run a phase in one turn is to reduce that count rather than to
overlap it.

**Count the builds before starting, because a phase fits one turn only if nothing is built twice.**
A clean build is ~95 s and a production lifetime run ~90 s idle, so a dozen of each is under an
hour and two dozen is not. That arithmetic is what §0's pre-flight is buying, and it is why a
satisfiability check (§0.5) is worth more here than anywhere: one unsatisfiable gate costs a
rewrite, a rebuild and a re-run.

## 5. Environment isolation

Each packet gets its own worktree, its own R library when it touches `odelia`, and its own scratch
directory. `plant` reaches odelia's headers through the *installed* package, so two agents installing
into one library overwrite each other's headers:

```sh
mkdir -p /home/user/lib-<packet>
export R_LIBS_USER=/home/user/lib-<packet>          # searched before the site library
Rscript -e 'install.packages("<odelia worktree>", repos = NULL, type = "source")'
```

**And the orchestrator's own verification needs its own worktree too** — a detached checkout at the
commit SHA, which nothing else can touch. This is not symmetry for its own sake: two concurrent
builds in one worktree left `src/*.so` half-written, and **loading a mid-write `.so` succeeds and
returns plausible wrong numbers** — `offspring 42.366121223872653 / 5042` against a true
`42.176246845059751 / 5105`. It has the size and character of a real result. Hit twice in Phase 1,
both times because a verification build ran in a worktree where an agent was still active.

**Verify an install by grepping the installed artifact, never by reading the install log.** A library
was found carrying an odelia with **zero** step-size accessors while its source worktree had 34, so
the packet's entire mechanism was absent from the tree being built against.

## 6. Work economy

A build and a production run are the most expensive instruments here and the least discriminating
(§3). So treat them as a budget: **batch the work, and spend a run where it can still change a
conclusion.** Before paying for one, ask what it would tell you that reading the diff, the record or
one translation unit would not. Usually that is one question at the end of a batch rather than one
per commit — and sometimes it is nothing, because the answer is already written down against the
same SHA. The bullets below are how that principle has cashed out in practice, not a checklist:

- **For a compile-only question, compile one translation unit with `-fsyntax-only`.** Measured: **10
  invocations at about 2.9 s each, 30 s of compiler time**, against roughly 13 minutes for a clean
  `compile_dll` of 24 translation units plus 2 minutes for a reference run. The same census by
  rebuild would have been over two hours.
- **`-fmax-errors=200` is the whole trick.** The default cut off after one group of errors and hid
  four others; raising it turned twenty visible errors into the full 41 and made the census
  meaningful rather than misleading.
- **Background processes are frozen between tool calls in this container.** `nohup … &` plus polling
  across calls makes no progress — a five-minute job showed 71 s of CPU after 40 minutes of wall
  clock. Run long work in the foreground with an explicit timeout, or inside one call that waits.
- **An expensive gate makes an agent unreachable.** A queued correction only lands at the agent's
  next tool round, so an agent blocked inside a one-hour call cannot be told to stop. Bound the cost
  when writing the packet; failing that, kill the process **by PID**, which returns the call and
  delivers the message.

## 7. Review

- **Re-run every gate.** An agent's "tests pass" is unverified until its output has appeared in the
  orchestrator's own session, in the orchestrator's own worktree. A false pass is worse than a gate
  not run. Where you choose not to re-run something, **say so explicitly** rather than implying you
  did.
- **Distinguish an agent's harness from its tree.** Several Phase 1 baselines were contaminated by
  the namespace problem in §3; the agents' comparisons were still sound because they used one form on
  both sides, but their absolute numbers were not. Re-measure on the namespace-bearing form.
- **A mechanical sweep over every diff before it lands** — `/home/user/p0/style-sweep.sh <worktree>
  <base>` covers doc-section references, issue tags, decorative nouns, banners, `xad::` inside
  `plant`, deduced-return-type lambdas, comment runs over two lines, and touched baselines or
  generated files — **plus reading every comment line the orchestrator did not write.**
- **The sweep reports candidates, not verdicts.** A hit on a line a diff merely *moved* is not a
  violation, and the arithmetic settles it: when a file move relocated 15 issue tags into a header,
  7 in the base header plus 8 in the base source equalled 15 in the tip, so the phase added none.
- **Some invariants are properties of the merge, not of any branch.** `grep -r 'xad::' plant/inst
  plant/src` returned five lines on every branch in isolation and nothing on the merged tree, because
  the helper that empties it was developed on a sibling branch. Check those at integration.
- **When an agent reports a contradiction, investigate against the code before overriding it.** Five
  times in Phase 1 the agent was right and the plan or the packet was wrong.
- **Hold your own edits to packet discipline.** Anything hand-edited and called non-semantic gets a
  bit-identical gate before it is believed — including a merge conflict you resolved by hand.
- **The cross-model tripwire on every merge, not at the end of the phase.** Phase 0's
  offspring-to-zero regression survived three steps because FF16 and K93 only ran once, at the end.
  A green TF24 suite is not evidence about the shared canopy: TF24 reaches the profile through
  `q_from_height` and never the raw two-argument form, so all three TF24 gates passed while FF16's
  offspring was exactly zero. **What caught it was a whole-lifetime FF16 run**, and no per-file
  suite substitutes for one.

## 8. Stopping is the product

Five packets in Phase 1 stopped without finishing, and every one was right to. Two of them falsified
statements in the plan. **A stopped packet with a diagnosis is worth more than a finished one that
papered over a contradiction**, and the practice only works if that is true in fact and not just in
the packet's wording.

What that requires of the orchestrator:

- **Say so when the packet was wrong.** Four of Phase 1's stops were caused by the packet, not the
  work. An agent that is told "your environment was broken and it was mine" reports the next problem
  faster.
- **Ask for the cost.** "Roughly what did your gates cost, and which of my gates were uneconomic" is
  how the 90 s-versus-7 minutes fact surfaced. An agent will otherwise absorb an unpriced gate
  silently.
- **Prefer a resume to a fresh packet.** An agent resumed with its context intact fixed a
  bit-identity defect in one round; the same correction as a new packet would have re-derived
  everything.
- **Do not reward a weakened gate.** When a gate fails, the wanted output is the numbers and a stop —
  not a tolerance that lets it through. Say this in the packet, and then honour it when it happens.

**Stopping inside a single turn cannot mean waiting.** When the whole phase is one turn there is no
next session to hand a stop to, so a stop resolves as: record the finding with its evidence, finish
every task that is *not* downstream of it, and say plainly at the end what was left and why. The
thing that must not happen is the stop quietly becoming a weakened gate because the turn wanted to
finish. **A phase that lands five of seven tasks with the other two diagnosed is a good turn; one
that lands seven with a tolerance widened to fit is not**, and the second is only distinguishable
from the first if the gates were written down before the work started.

## 9. Integrate, and record

One integration branch per repository per phase. After each merge, **verify every change is present
by reading the merged tree** rather than trusting the auto-merge, then build once and run the
tripwire. Check the arithmetic of the merge: if four packets added 4, 11, 27 and 7 assertions to a
264-pass baseline, the merged tree should show 313, and anything else means a merge lost or duplicated
something.

**Some work has no packet, and it is the integrator's.** Every Phase 1 allowlist was code and tests,
so nothing updated `odelia/AUTODIFF.md`, which the plan makes the home for the System requirements
that this phase *changed*. Nobody could have done it but the integrator, and it was missed. Before
closing a phase, list the documents the plan assigns and check each against what landed.

**Cite a symbol, not a line, and a document will not need maintaining.** Every line citation
in `build-plan.md` §2.8, §2.9 and §3 had drifted by the end of Phase 1 while every claim
they supported was still true — `patch.h:727-775` had become `867-915`, `scm.h:309` had
become `320`. A citation is only stable if it names something that cannot move:

- **live code: the symbol.** `Patch::load_ode_step`, not `patch.h:888`. It survives every
  edit, it is greppable, and it tells the reader what to look for rather than where to look.
- **archaeology: a commit and a path.** `git show 903b8292:inst/include/...` is frozen by
  construction, so a line number is safe there and nowhere else.
- **a number: the command that produced it.** A count someone can re-derive needs no
  maintenance; a count they must trust rots silently.

The cheapest way to stop a citation drifting is to delete the second copy of the fact it
supports, which is what one home per fact is for.

**Re-bless nothing** — recording a shift is the job, accepting it is the owner's. Phase 1 ended
bit-identical, including the one shift the plan had sanctioned, so there was nothing to accept.

Recording is part of "done", not a pass afterwards. `implementation-notes.md` takes the commit, the
build, the gates as run, the shift where numbers moved, and **anything the item revealed that the
plan did not predict** — that last field is what earns the file, and in Phase 1 it was most of the
value. `build-plan.md` and `tf24-correctness.md` take a commit tag and nothing else, **except that a
forward-pointer the phase has disproved gets a one-line correction** with its evidence. Reports are
reference, never edited to track progress, corrected the same way.

## 10. Standing hazards

Build and measurement:

- `pkgbuild::compile_dll()` defaults to `-O0` and appends its flags last; pass `debug = FALSE` and
  check a compile line ends at `-O2`. The same tree at `-O0` differs by 0.145% in offspring and
  0.79% in accepted steps.
- `rm -f src/*.o src/*.so` before every build. R's make does not track header dependencies and the
  core is header-inline, so a header edit otherwise fails to compile in — a silent false pass.
- **If a number moves unexpectedly, clean-rebuild and re-measure before believing or reporting it**
  (§5).
- `library(odelia)` from a real install, never `load_all` for odelia; `load_all` the plant tree under
  test; `Sys.setenv(TESTTHAT_PARALLEL = "false")`.
- R buffers `cat` to a redirect. Poll for the process to exit; do not read progress out of the file.
- `pkill -f <pattern>` and `pgrep -f <pattern>` match the shell running them. Kill by PID; poll
  `kill -0 <pid>`.

Model and code:

- `run_scm(collect = TRUE)$species` is the flat per-step-per-node table; `$species[[1]]` is a column.
- **Two like-typed positional arguments of unrelated meaning are a silent-swap hazard**, and
  templating is when to re-check the call sites by meaning rather than by type. This shipped a
  regression once: a meaning changed then reverted left one caller mismatched, it compiled, and a
  model's offspring went silently to zero.
- **The stage is not a pure function of `(y, t)`.** `Species::compute_rates` writes the inflow
  boundary node on every call and `Species::compute_competition` reads it, so the light field depends
  on a density carried from the previous evaluation. A **rejected** step attempt writes that scalar
  while producing no accepted step, so **no pinned replay can reproduce an adaptive run**, and the
  reverse pass's stage rebuild inherits the same problem. P2.7 closes the lag and is therefore a
  prerequisite for the reverse pass rather than a refinement.
- **`fl(fl(t + h) − t) ≠ h`.** A step size is not recoverable by differencing recorded times; at
  `t ≈ 100` the low four decimal digits are gone. Record `h`.
- Registering a tape's inputs **after** `newRecording()` gives silently zero adjoints. Register
  first.
- Never give a deduced return type to anything returning an active value; and beware `-> double` on a
  lambda in templated code, which silently passivates.

---

## 11. Phase 2, in one turn

Seven tasks, four of which move forward numbers, landing as **one re-blessing**. That is the plan's
own requirement and it is what makes the phase a single unit of work rather than a sequence of
sessions: a per-task re-bless would bless four times against a moving baseline.

### 11.1 The order is forced, and one constraint is not in the plan

```
    measure  ── one instrumented build, one run: the gate-crossing census AND M4's value half
       |
    P2.7  boundary reordering (from spike/boundary-acyclic)
       |
    P2.1  step (1) fractions ── step (2) uniform-65 ── step (3) delete rescale_spline
       |                                                    |
       |                                              P2.2  slope reduction
       |                                                    |
       |                                              P2.3  Hermite in ResourceSpline
       |                                                    |
    P2.4  step (1) done above ── (2) two passes ── (3) cohort grid ── (4) delete + NEWS
       |
    P2.6  collar polish          P2.5  attribute rescale_spline's cost
       |
    one re-bless + the cross-model tripwire
```

**P2.7 must precede P2.4, and the plan does not say so.** The plan gives only "P2.4 before P2.6".
But both tasks restructure `Species::compute_rates`, and `spike/boundary-acyclic` has already moved
`Node::compute_initial_conditions` out of it into the field build via `Patch::compute_boundary_nodes`
— which is exactly where report 04 §7.2's two-pass pseudocode wants the boundary node to sit, because
the lowest cohort differences against it. Landing P2.4 first means placing that call inside
`compute_rates` and then moving it out again, restructuring one function twice and invalidating the
first restructure's bit-identity gate. Taking P2.7 first also hands P2.4 the *more current* boundary
neighbour its stencil wants, which `implementation-notes.md` records the spike as supplying.

**P2.4 before P2.6 is about measurement order, not files.** P2.6 touches `leaf_model.cpp` alone, so
it can be written in parallel with everything above it and merged last. What it may not do is land
before P2.4's numbers are taken: it widens the golden-section bracket a hundredfold, and report 04
§5 records that develop's probe survives differencing a staircase only because the comparison
pattern is locally constant at the *current* bracket. Interleaved, P2.4 step (2)'s bit-identity gate
is asserted against a moving leaf and M4 stops being attributable.

### 11.2 Three things are already done that the plan or this document records as owed

Checked in the tree, not inferred — §0.6's rule run in the opposite direction.

- **`hermite_interpolator` is complete.** It has the `set_nodes`/`set_data` split P2.1 asks for, and
  the active-position read in *both* `eval` and `value_and_slope`, grafted as
  `value + slope · (u − to_passive(u))` with a `static_assert` that rejects an active position
  against `S = double` — the silent-severance case M1 measured as exactly zero. It is one
  type-dispatched function rather than §2.8's `eval`/`eval_with_query_derivative` pair, which is
  better: there is no wrong overload to call. **This document's Phase 1 tail recorded it as
  outstanding and was wrong.**
- **P0.1 has landed**, so P2.4's two-pass restructure is value-neutral (report 04 §7.3) and the
  leaf is order-independent.
- **P0.7 has landed**, so P2.2's reduction may query the field's slope at the ground knot.

### 11.3 Two measurements before any code, and they share one build

Both are instrumentation-only additions to `species.h`, both want one production run, and neither
needs the other's output. **One build, one run, two answers** — the §6 economy applied where it
actually pays.

1. **How large does the cohort-grid stencil get where the spacing is small?** This was framed as
   "does a gate crossing land beside a sub-`1e-4` spacing", on the premise that TF24's growth gate is
   hard and un-smoothed. **That premise is false, and the framing goes with it.** `TF24_Strategy`'s
   growth path is `Ppos = ½(P + √(P² + storage_prod_eps²))` times a logistic reserve gate, with
   `storage_prod_eps = 1e-4` — the hard `net > 0` cutoff was replaced by `#517` and report 00 §4.3
   records it. The corpus said otherwise because it grepped for the *helper* `smooth_positive`, which
   exists nowhere in plant's headers; report 02 C1 attributes those sites to the **AD branch**, and
   the claim was carried across to a develop-tree conclusion. TF24's only hard `net > 0` gate is
   inside `establishment_probability`, which is P0.6's, and it sets the boundary node's density
   rather than any cohort's `g`. `test-node.R` states the smoothing in its own comment.
   So there is no switch for two neighbours to sit on opposite sides of, and what remains is the
   quantitative question: the spacing's measured minimum is 8.2095e-06 with 23.5% below 1e-4, and a
   large enough growth-rate difference over that divisor is still an O(1e5) term develop's sub-grid
   probe cannot produce, because both its evaluations are the same cohort. **That question is
   answered by M4's own census**, so the two measurements are one run and not two.
2. **M4's value half** — `Species::growth_rate_gradient(i)` beside the existing `Node` one, both
   logged on one production run. This is P2.4 step (1) and it is the number the re-blessing is
   argued against.

### 11.4 The gates, and the two that would otherwise be unsatisfiable

| | gate | note |
|---|---|---|
| P2.7 | `derivs(y, t)` twice, **bitwise**, 0 of 753 components; a third evaluation moves ground light < 1e-6 relative; light-field shift within the boundary term's own 3.5e-04 | verify in **light at the boundary node**, never in offspring — the predicted effect is two orders below the 0.145% the controller re-rolls offspring by |
| P2.1 (1) | bit-identical **within an introduction interval** | **not whole-run.** Across an introduction `construct_spline` re-refines and the count runs 33–129, mean 58.4 (report 03 §1b). A whole-run bit-identity gate here cannot pass, and asserting one costs a rewrite and a rebuild |
| P2.1 (2) | crown-mean light shift within M3's band — worst 1.7e-03, median 1.6e-06 | the deliberate re-bless; this is the step that removes the carried knot set |
| P2.1 (3) | the purity probe **bitwise** at all three models | with rescaling gone and P2.7 landed, both path dependences are closed; neither alone is sufficient |
| P2.2 | agreement with a tight central difference of `compute_competition` across `eta` ∈ {1,2,4,8,10,12} and one non-integer | plus: the two sums add the same terms in the same order, **checked rather than asserted** — a value and a slope from differently-associated sums disagree in their last bits, which is this report's own defect reappearing in floating-point association |
| P2.3 | O(h⁴) on value, O(h³) on slope, **on a smooth test field** | the production fraction set is uniform and does not align with the cohort tops where `Q(z/h)` breaks the field's derivative, so the production rate is about `h^2.5`. Record it beside the gate; it is a rate, not a penalty — uniform beats cohort tops 22× at matched count |
| P2.4 (2) | bit-identical | the step that separates "I broke the loop" from "the value moved" |
| P2.4 (3) | `log_density_dt` matching M4, with report 04 §2.2's conservation diagnostic presented alongside | a sub-grid probe leaks individuals at `O(dh g'')` and the cohort grid does not — that is the forward-model argument the re-bless rests on |
| P2.4 (4) | two pinned tests **rewritten, not relaxed** | `test-node.R`'s backward-difference assertion *is* the sub-grid stencil's definition, so it has no subject under the new one. Four properties replace them, and the identity `log_density_dt + mortality_rate == -d(log dh)/dt` is the only one that reads the dynamics rather than the arithmetic, so it is the one that would catch a staggering error |
| P2.6 | `\|R\|` < 1e-07 at every sampled state; the polished point independent of the bracket tolerance; benchmark no worse | two traps: `dprofit_droot_collar_psi` leaves the operating-point outputs at its own probe point, so the loop must restore them, and it reads `psi_soil_inverted_`, which only `prepare_collar_solve` refreshes |
| P2.5 | the forward benchmark after P2.1, with the difference attributed | **the 3.5 s share is anchored to a 59.5 s pre-`#517` run and means nothing until re-taken** against the gate number. This is `aornugent/plant#68` |

### 11.5 One re-bless, and the tripwire is part of it

Everything above lands together, at the pinned build, and the composite shift is recorded with the
per-item shifts beside it. Phase 0 is the reason to expect the composite to be *smaller* than its
parts: four individually positive shifts summing to ~1.9% composed to +0.0856%, because most of each
individual figure is the adaptive controller re-rolling rather than biology.

**FF16 and K93 run whole-lifetime in the same pass, not at the end of the phase** (§7). P2.4, P2.7
and P2.1 are all family-wide, and Phase 0's offspring-to-zero regression survived three steps
because the other two models ran only once, at the end. A green TF24 suite is not evidence about
shared code.

### 11.6 The budget

About **nine builds and ten production runs** if nothing is built twice: one for the shared
measurement, one for P2.7, three across P2.1's steps (P2.2 and P2.3 ride the third, since their
gates are unit-level and need no production run), two across P2.4's, one for P2.6, one for the
merged tree. At ~95 s a build and ~90 s an idle TF24 lifetime — FF16 and K93 are 209 and 240 steps
and nearly free — that is well under an hour **serially**. It is several hours as three concurrent
lanes, per §4. Build one at a time.

### 11.7 Carried into the phase, and not covered by any task

- **`max(S, 0)` on storage is a derivative discontinuity active on 13.96% of records, and no task
  fixes it.** Report 00 §9b measures it: storage genuinely goes negative (min −2.249e-03 against a
  median 1.756e-04), and develop's own comment claiming the outflow gate floors storage at zero
  **does not hold** — once `S < 0` and `|S|` is comparable to `1e-3·S_max`, the factor approaches 1
  or changes sign and the deficit drains at full rate. The clamp zeroes the carbon → mortality →
  survival → density channel on all 14%, which is squarely on every census metric's gradient. Report
  00 §10 lists fixing it as its second priority; `tf24-correctness.md` P0.5 carries the incidence in
  its table but **omits it from its own summary of rows with nonzero incidence and no recorded
  treatment**, which is how it fell through. Phase 2 is the re-blessing window, so it rides here or
  waits for the next one — and that is the owner's call, alongside the establishment gate and the
  respiration double-count.
- **Aux has two owners** — the operating-point transfer and the diagnostics a user reads. A
  functional reading `E_up_` through aux would give the cohort block a seventh output row.

---

## Where Phase 2 left things

`p2/phase-2` carries **P2.7, P2.1, P2.2 and P2.6**; P2.5 is a measurement and is answered. **P2.3 and
P2.4 are written, gated and pushed to their own branches, and deliberately not merged** — each is
blocked on one decision that is the owner's, not the orchestrator's.

    plant   p2/phase-2      derivs(y,t) bitwise pure at all three models
                            offspring 42.192676883315706, 4 854 steps, +0.039%
                            23.90 ms/step against a 22.76 baseline, so +5.0%
    plant   p2/p2-hermite   numerics pass; withdraws two shading models
    plant   p2/p2-stencil   correct by its own identity; moves offspring 10.3x

The superproject pointer stays at Phase 1 on purpose: the phase is not closed, ten assertions await
one re-blessing, and pointing at it would say otherwise.

**Four decisions are owed, and none is a baseline.**

1. **The box shading models.** `flat-top-box` and `flat-top-soft-box` route competition through
   `leaf_area_above`, a step and a smoothstep, so `q` is not their kernel's derivative and a Hermite
   over a step is not obviously the right object. P2.2 refuses them; P2.3 then stops them running at
   all. Either they are withdrawn, or the field falls back to a value-only build for them — which is
   two evaluators and a new mechanism. FF16 and K93 only; TF24 already rejects both.
2. **P2.4's 10.3× offspring move.** Report 04 §8's own falsifier. Two measurements would adjudicate it
   and neither has been taken: §2.2's conservation diagnostic under both stencils, and §8's K93
   comparison with the transport derivative present and absent.
3. **The two `test-patch.R` assertions** at 1e-21, where the patch's node and an externally-seeded one
   are now seeded in different fields.
4. **Whether M3's 1.7e-03 band is absolute or relative.** P2.1's step (2) is inside it read one way
   and 20% over read the other, and M3 does not say which it measured.

**What the phase taught about running one, beyond the tasks.**

- **A mean and an sd are the wrong summary for a quantity whose effect is set by its tail.** M4 read
  as a modest perturbation at mean −0.062, sd 1.878; the census's own max of 142.85 against the
  sub-grid's 1.51 is what actually drove a 10.3× move. The census recorded both and the packet was
  briefed on the wrong one — by me.
- **A packet boundary can manufacture a regression.** P2.6 step (1) without step (2) is +42% per step;
  with it, −1%. The plan says the four value-movers land together, and this is why.
- **Two packets caught stale premises in their own briefs.** A reference number from before a commit
  the tree already carried, and an instruction to remove code this corpus records as wrongly removed.
  §2.9's "its own baseline first" caught the first; reading the notes caught the second.
- **Test a property, not a configuration.** P2.6's bracket-independence test gated a changed default
  without being touched, because it was written against the residual. My own derivs-twice gate was
  vacuous for P2.1 for the opposite reason.
- **Editing a worktree while it is building silently relabels which arm you measured.** Same family as
  the mid-write `.so`.
- **Function-pointer identity is not a discriminator** in a header-inline codebase without LTO: the
  weak-symbol addresses did not merge across translation units.
- **Name the arm a ratio is against, every time.** I reported the phase as faster than baseline by
  quoting it against P2.7's 24.3 rather than the pre-phase 22.76. It is +5.0%, inside the band and
  not a saving. §8b already insists every timing gate is a ratio measured in one session; what this
  adds is that the *denominator* has to be named as carefully as the numerator.

---

## Where Phase 1 left things

Both integration branches are pushed and the superproject pointers reference them.

    odelia  p1/odelia-integration    322 pass, 0 fail, 0 error, 2 skip
    plant   p1/phase-1

| | offspring | accepted steps |
|---|---|---|
| plant `7b05b55e`, before the phase | `42.176246845059751` | 5 105 |
| **`p1/phase-1`, everything merged** | **`42.176246845059751`** | **5 105** |
| FF16 | `19.825535760483262` | 209 |
| K93 | `0.030546712014675573` | 240 |

**The whole phase is bit-identical.** The environment's aux widening — the plan's one sanctioned
shift — moves no assertion, because nothing reads the environment's aux.

Owed, all recorded with evidence in `implementation-notes.md`, none blocking:

- **`Replayable` should be `Recordable`.** Its only real implementor records and never replays.
- **The active build's value gate is unsatisfiable as written** (§0.5), and 41 compile errors at 33
  sites are documented in six groups. The largest is `std::`-qualified math on an active argument.
- **`plant::Environment` is half-templated** — light carries `S`, the whole soil water balance stays
  `double`. A decision is owed before anything differentiates through the soil.
- **Thirteen registered traits will read as exactly zero** until the leaf's supplied Jacobian exists,
  because `Leaf` is `double` and takes them by value. By design, and dangerous precisely because
  exactly-zero is this design's worst failure mode.
- **Two unguarded `pow` sites** — `CanopyShape::Qp`'s `eta_inverse_` and the soil curves' `n_psi`.
  Neither exponent may be registered as a target until guarded.
- **`ResourceSpline<S>` promises an active height its interpolant cannot accept**, which is the seam
  the Phase 2 interpolant swap lands on rather than a defect to patch.
- **`Solver::run()` serves two operations through one door** — a recorded trajectory and a
  caller-supplied time grid — and the vector alone does not say which. Two entry points are owed.
  These are not superseded stubs: the three `Solver_*` entry points were introduced in the same
  commit as `compute_jacobian` as one deliberate layering, and that commit retired the actual spike.
- **`ARCHITECTURE.md`** is still silent on this phase. *(The second half of this item — that the
  hermite lacked its pair of query readings — was checked against the tree and is false; §11.2.)*
