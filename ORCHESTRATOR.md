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

**A baseline is a property of a commit, so write it as one.** Twice in Phase 3 a packet was given an
odelia suite count from a different tip than the one it was handed — 322 (Phase 1's close, before the
audit), 327 (`p1/audit-fixes`), 330 (the tape branch, which adds three tests). All three are recorded
correctly; what was not recorded is which tip each belongs to, which is the only part a packet needs.
Quote the SHA beside the number.

**And a baseline is a property of a commit *and a configuration and the script that produced it*.**
Phase 3's wave 1 raised a false alarm because I handed TF24's configuration to all three models:
FF16 came back 56.30/214, which is not a regression but FF16 at its own defaults, the shape of the
recorded develop baseline 56.279/214. The corpus even records which script the other two numbers came
from — `ff16k93.R`, with its own hyperpar and lifetime. Quote the SHA, the configuration and the
script, or the number means nothing. Third baseline error of mine in that phase.

**A census reaches only what it names.** Explicit instantiation of a class template instantiates its
**non-template members only**, and odr-use from a container reaches only the members it calls. So a
member template is gated only by naming it. Wave 1 found three ungated seams that way —
`Individual`'s three iterator serialisers — and one of my own standing probes was blind to the very
packet it was gating. "Census from the outermost consumer inward" is necessary and not sufficient;
name the member templates explicitly.

**And the third half, which Phase 3 paid for three times: run the gate on the unmodified tree before
you send it, and confirm it produces a number you recognise.** Asking "what would make this pass
vacuously" is not enough, because it is answered from the same understanding that wrote the gate. Phase
3 shipped three gates that could not fail, all the orchestrator's, and they share one shape — each
specified *the quantity the author was thinking about* rather than **the quantity that moves when the
feared thing happens**:

| the gate | what it could not see |
|---|---|
| `template class TF24_Strategy<active_scalar>` as the active-build census | it never instantiates `Individual`, so it was blind to the container holding the state the block differentiates |
| a reused tape's adjoints against a single call's | `newRecording()` leaves adjoints **correct** while leaking a slot per input per call; the discriminator was the recording *size* |
| an FF16/K93 whole-lifetime tripwire | written without `add_strategies`, so both models ran empty and it printed no numbers at all |

Each would have died in the ten seconds a baseline run takes. The second is the one to remember, because
it was gating a change whose whole purpose was reuse: **when a change is about reuse, assert the
resource, not only the answer.**

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
6. `docs/reports/00`–`04`, `07`, `10`. **Read them twice: once for the design, and again at review
   time against the code.** Report 10 supersedes report 04's *conclusion* — read 04 for its
   derivations and measurements, which stand, and 10 for what they do and do not license.
   Report 01 §3 names the carried boundary density that sank three attempts at
   the trajectory store; it was read at session start, and its relevance only became visible when a
   measurement demanded an explanation. A report read once is orientation; a report read against a
   diff is a review tool. **Start with the head of each: reports 01, 02, 03 and 04 now carry
   corrections there**, and report 03's is a claim its own three Phase 2 tasks rested on.

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

**This section's economy inverts when the phase moves numbers, and Phase 2 did.** Phase 1's gates
were blind *because* the phase was bit-identical by construction — templating at `S = double`
generates the same object code, so no value gate could see the hazards, and reading found what six
gates could not. Phase 2 was the opposite: three tasks changed a forward number, and the tasks' step
decompositions existed precisely so that a bit-identity gate discriminates. **Skipping the
bit-identical intermediate throws away the attribution the decomposition was bought for** — it is the
only thing separating "I broke the loop" from "the value moved by the predicted amount". Phase 2 paid
that twice over: the two-pass transport restructure was bit-identical, which is the whole reason a
10.3× move could be attributed to the stencil and to nothing else, and P2.6's step (1) measured at
+42% per step where step (1) and (2) together cost −1%. So in a value-moving phase what gets batched
is the **re-blessing**, and a step whose own claim is bit-identity has earned its run.

**And a step whose claim is bit-identity has to be checked for whether it can be.** P2.1's step (1)
was specified as bit-identical and arithmetically could not be — `u_k = x_k / height_max` is itself a
rounding, so the rebuild computes `fl(fl(x/H₀) · H₁)` against `fl(x · fl(H₁/H₀))`, and 572 of 8 256
knot positions land 1–2 ulp apart. That is §0.5 in the one place a phase like this invites it.

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
- **The sweep cannot see a comment the phase made false, and that is the one to read the diff for.**
  Phase 2 deleted the light interpolant's rescale path and left three comments telling the reader to
  prefer it. Nothing about those lines changed, so every grep in the sweep passes them; only reading
  the neighbourhood of a deletion finds them. **A deletion's blast radius is prose as well as code.**
- **Read the reports against the code at phase close, not only at phase start.** §1 item 6 says to
  read them twice and this is the second time. The failure mode it catches is specific: a report whose
  *conclusion* stands while a sub-claim inside it has been falsified. A replaced conclusion gets a
  banner from the session that replaced it, but a falsified sub-claim lands in the notes and the plan
  and leaves the report — the section that owns the mechanism, the thing §0.2 sends packets to read —
  still asserting it. Phase 2 found one in each of reports 01, 02 and 03, and report 03's was the
  claim its own three tasks rested on.
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

**Re-bless nothing until the owner accepts the shift** — recording it is the job, accepting it is
theirs. Phase 1 ended bit-identical, including the one shift the plan had sanctioned, so there was
nothing to accept. **Phase 2 is where the rule met its case, and what it resolved to is worth
stating**: every moved assertion was recorded with both readings and left *failing* through the
phase, the owner accepted, and the re-blessing then went in as one pass at the end. So the rule is
about ordering rather than prohibition — a re-blessing is a deliverable of a value-moving phase, and
what may never happen is a baseline moving before the shift that moved it has been recorded and
accepted.

**Three kinds of failing assertion come out of a value-moving phase and only one of them is a
re-blessing.** Phase 2 hit all three and conflating two of them cost a rebuild.

| | what it is | what it takes |
|---|---|---|
| a moved baseline | the same assertion, a shifted number | re-bless, with the shift recorded |
| a subject that stopped existing | the assertion can no longer express what it tested | **migrate the test**, and check first whether a capability went with it |
| a design choice | two readings, and the assertion encodes one | leave failing, record both, the owner's |

`spline$size` returning NULL is the first kind. `spline <- interpolator` erroring is the second, and
reading it as the first shipped a segfault and a lost R capability into a re-blessing pass.

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

## 11. Phase 3, and why it is not Phase 2's shape

Phase 3 is the reverse pass: five tasks that build one gradient, verified against §2.5's V1–V4.
**"Where Phase 3 stands", below, is the state; this section is the method and the order.** P3.4 landed in
Phase 1, so the task list is five and not six.

### 11.1 It does not fit one turn, and the constraint is dependency rather than size

Phase 2 fitted one turn because six tasks were **independent to write** and only their builds were
serial — §4's "write in parallel, build serially" was available. Phase 3 is a chain: P3.1's closed-form
steps are step (b)'s stub's callers, P3.2 fills the stub, P3.5 drives it from the stepper, and P3.6 seeds
it. Fanning that out thrashes, because each downstream agent rebases onto a moving base and its gate
measures the rebase.

**And every gate is an instrument that does not exist yet.** Phase 2's gates were a forward run and a
suite. V1 needs a whole-`Patch` recording; V2 needs the trajectory store plus a block; V3 needs
`step_adjoint` driving plant; V4 needs a re-run finite difference at production lifetime, which for 51
traits is **102 forward runs** — §8b is explicit that V4's verification is the expensive half of the
acceptance test rather than the cheap one.

So plan it as **several turns with one task each**, and treat the per-task V-check as the turn's product.
The thing that must not happen is a turn that lands two tasks and can attribute a V-failure to neither.
*Evidence that this is the right reading: the phase's prerequisites alone took six packets and about
fifteen builds, and none of them was one of the five tasks.*

### 11.2 The order, and the plan names none of the first four steps

```
    the prerequisites ── ALL LANDED, bit-identical, integrated (see the state section below)
       |
    Patch::rebind_from ── step_adjoint hard-asserts on it and it does not exist
       |
    Environment's cohort-reads triple ── n_cohort_reads/cohort_reads/set_cohort_reads,
       |                                unwritten. Five of the block's 141 declared inputs
       |                                are soil potentials and today they are passive, so
       |                                d(uptake)/d(psi) has nothing to attach a partial to
       |
    P3.1  (a) soil ── (c) light knots ── (d) allometry,  step (b) stubbed        V1
       |
    P3.2  (1) block, leaf held ── (2) envelope + flux ── (3) the waist ── (4) translation ── (5) pinned
       |                                                                        V2, V2L, T4-T6
    P3.3  the leaf's own parameter rows
       |
    P3.5  the stencil's adjoint, driven from Step::step_adjoint                  V3
       |
    P3.6  census<Psi>, the entry point, agents.md §13                           V4
```

**P3.5's transport adjoint is designed and its premise was false**, which is the one correction inside the
task list worth carrying forward. Report 04 §5 says differentiating develop's sub-grid probe at an active
scalar yields the derivative of the discretisation actually solved: true of the scheme, false of the code,
which was passive at three points. The probe now carries the scalar and the quotient helpers refuse a
passive integrand. **The design to build: record both evaluations and let the tape form the quotient**, so
`lambda_g` needs no hand-written seed — two block recordings per cohort per stage, which is report 10 §6's
cost. The conditioning is inherited and is about `1e-10` absolute, so **gate that channel against a finite
difference of the same quotient, never against an analytic `dg/dh`**.

### 11.3 The gates, and the four that would otherwise be unsatisfiable or vacuous

§0.5 and §0.6, applied before anything is sent.

| | gate | the trap |
|---|---|---|
| V1 | steps (a), (c), (d) against the matching part of one whole-`Patch` recording at one state, blocks stubbed | add the three contributions **one at a time** — they are separable contributions to one accumulator that is nonzero without any of them, so a dropped term gives a plausible gradient |
| V2 | one cohort's block at one stored step against a finite difference of the same block, **leaf held constant** | **stage 0 only.** A block lives at a stage and stage states are rebuilt, so verifying above stage 0 needs the rebuild working first — which is V3's subject |
| V2L | the leaf's partials against report 02 §6.9's three identities | **not a finite difference, and not a preference.** A re-run FD resolves the collar's response to about four digits and the residue under test is 4–9% of it, so a disagreement reports the reference rather than the scheme |
| V3 | one step's `lambda_y` against a finite difference of one step | a lost tableau term is **silent and has no measured signature** — a whole-run disagreement would not localise it and there is no magnitude to recognise it by |
| V4 | census and R0 at `max_patch_lifetime = 105.32` against a re-run FD, under 2 GB peak | **the reference straddles the establishment gate**, which closes on 23.1% of boundary-node stage evaluations confined to `t ∈ [3.22, 8.54]`, and a `1e-9` trait perturbation flips it. Choose states and step sizes outside that window. A property of the reference, not the scheme |
| T4 | `in.size() == state_size() + n_cohort_reads() + ad_parameters().size()`, and a pack/unpack round trip | it must assert the **dependent aux slots** too — `competition_effect` and `height_inverse` are derived by `set_state`, not packed, and an unpack bypassing `set_state` leaves `area_leaf` stale |
| T5, T6 | knot-adjoint and trait-adjoint accumulation, **asserted as values** | a finiteness check passes on the failure these exist for. The trait case has a measured signature — **41–51%** of the truth, correct sign, nothing thrown; the knot case has none, which is the argument for a value assertion rather than against |

**The vacuous-gate question, asked concretely for this phase.** **Exactly zero is this design's worst
failure mode**, because it reads as an answer. Two ways to get one: registering a tape's inputs *after*
`newRecording()`, and a `double` intermediate anywhere on a channel. So for every gate, ask what it reports
when the channel under test returns exactly zero — and where the answer is "it passes", the gate needs an
explicit assertion that the adjoint is **not** zero. odelia's own active-position test already does this
and is the precedent to copy. **Phase 3's prerequisites shipped four gates that failed this test; §0 now
carries the three rules that come out of it.**

### 11.4 The budget, re-costed from measurement

Both of §8b's soft numbers are now measured. The multiplier is **8x marginal, 5.56x at the block's size
with the tape reused** — flat in block size, which the budget assumed correctly, but not at the assumed
value.

| term | | |
|---|---|---|
| rebuild the stage states in `double` | one forward RHS per stage | ~115 s |
| the leaf's partial derivatives | 3.9 M, 14–21 µs | 55–82 s |
| record and sweep, **twice** per (stage, cohort) | 3.9 M × 6 µs × 5.56 × 2 | ~260 s |
| | | **~430–460 s** |

**A gradient is 3.7 to 4.0 forward runs, and the saving against 51 traits by central difference is ~26x.**
V4's re-run finite difference remains the expensive half of the acceptance test. **Peak is unaffected and
now measured**: 46 MB of trajectory plus a block's recording of **52 kB**, flat in the number of output
adjoints seeded, so the 2 GB gate has four orders of headroom.

**One caveat that is live work, not a note.** The reused tape is **demonstrated, not realised** — nothing
holds one yet, and calling the tape-less overload inside the cohort loop restores the old cost with no test
complaining. Whoever writes P3.2's loop must hold one tape across it.

### 11.5 The documents the plan assigns, and Phase 1 missed one

§9's "some work has no packet, and it is the integrator's". Every Phase 1 allowlist was code and tests, so
nothing updated `odelia/AUTODIFF.md` — which the plan makes the home for the System requirements that phase
*changed*. Check each before closing the phase:

| document | what Phase 3 owes it |
|---|---|
| `odelia/AUTODIFF.md` | the System requirements including `ode_rates_adjoint`, **plus Phase 1's arrears**, and now `active_scalar` and `Rebindable` |
| `odelia/ARCHITECTURE.md` | still silent on the `Tape` link as this build uses it |
| `plant/agents.md` §13 | P3.6 requires it, and the acceptance test is partly a **count**: a developer reads §13 and adds a fourth census metric without touching tape code |
| `plant/NEWS.md` | `stand_gradient` is new R surface, so it is an entry even though nothing breaks |

### 11.6 Carried in, and none of it is Phase 3's to decide

The list is in the Phase 2 tail — the storage clamp, the establishment gate, the respiration double-count,
`aornugent/plant#69`, aux's two owners. Two bite *inside* Phase 3 rather than waiting for a re-blessing
window, and both land on P3.6:

- **The establishment gate is V4's reference problem** (§11.3), so P3.6 cannot be verified without a
  position on it, even though the decision is the owner's.
- **The `mortality = Inf` cohorts carry a zeroed derivative into the census.** 327 of 10 153 records at
  survival exactly zero, from `t = 7` on. The zero is genuine — the cohort is dead — and the proposed
  treatment, dropping such a cohort from the reduction, **changes the census value** and not only its
  gradient. So it wants the owner and a re-bless *before* V4, and it must not become a quiet guard inside
  `census<Psi>`.

---

## Where Phase 3 stands

**Integrated and verified, but not closed.** Every prerequisite is done, **P3.1 is written**, and
P3.2 through P3.6 are not started.

    plant   p3/phase-3             b16068c1   ten packets, pushed (wave 1 fast-forwarded from p3/wave1)
    odelia  p3/odelia-integration  fdccd7b    two packets, pushed, unchanged by wave 1

The superproject pointer moved in `6b5238b`, staged alone. **The whole phase is still bit-identical** —
TF24 `42.179817344974609` / 4 798, FF16 `19.834058960443031` / 209, K93 `0.030538172107758225` / 240 —
and `derivs(y, t)` twice is bitwise pure, 0 of 1137. plant 2 924 pass / 0 fail with 6 named pre-existing
errors and 10 skip; odelia 334 pass / 0 fail / 2 skip.

**What the phase has bought.** `Patch<TF24_Strategy<S>, TF24_Environment<S>>` instantiates at the
adjoint active scalar, and **the active forward rate path now compiles: the ordinary-use probe reads
0**, from 18 at the wave's base. The standing explicit-instantiation probe reads **2**, and both are
`prepare_strategy` refusals reached at *construction* — take the patch by reference and the rate path
gives 0. That is architecture rather than a residual error, and it is independent confirmation that
`rebind_from` is the only route to an active `Patch`. Deep-crown shading is **refused** at the active
scalar rather than carried, which is a scope reduction with its restoration conditions recorded.
`Patch::rebind_from` and the cohort-reads triple (135 reads for TF24) are landed, so the soil potentials
are no longer passive. P3.1's steps (a), (c) and (d) are written and each closed-form contribution is
gated against a finite difference of the forward quantity it transposes, agreements 3.1e-11 to 1.04e-08.
The cost model remains **~430–460 s, 3.7 to 4.0 forward runs, a ~26x saving**; the pinned-leaf question
is settled at 0 in 7.35 M.

**What remains.** P3.2 through P3.6. **V1 is available once step (b) exists** — it compares against a
whole-`Patch` recording, and the recording needs the block, which is P3.2 step (1)'s held-constant leaf.
So V1 is not taken and is not claimed, and P3.1's finite differences are the weaker instrument standing
in for it: they verify each transpose against its own forward quantity and say nothing about the
decomposition adding up.

**One ruling taken, with a number and a falsifier.** The knot grid stays fixed and passive — report 03
C1's reason, committed at P2.1 — so the plan's `height_max` term does not exist. The measured cost is a
gap of about **87% of the tallest cohort's height adjoint**, far larger than C1 assumed, and **C1's
convergence-with-knot-density claim is still unmeasured and is now the falsifier**. V1 is the
instrument. Evidence for all of the above is in `docs/implementation-notes.md` under *Phase 3, wave 1*.

**Owed out of wave 1, each with the reason it was not taken**, and none of it blocking: the
`field_ptrs()` / `ad_parameters()` unification onto one yml-ordered table (a refactor, wrong wave);
`prepare_strategy`'s `throw` becoming `util::stop` (observable on the passive path, wants its own gate);
deep-crown restored as a differentiable arm (needs `qk.h`'s two vector members scalar-generic *and* the
`Leaf` write-back relocated, and the second is P3.2's boundary); C1's convergence measurement; the
cohort-reads triple's pre-build state, which reports 135 against un-rebuilt knots and throws; a stale
`tf24_environment.h` comment that only the merge makes false; and `FF16_Strategy()$eta_c` printing
nothing, the third instance of `sprintf`-on-empty silence.

**Three things carried into it, each with the reason it is not yet decided.**

- **The competition family's `height` argument stays `double`.** A sound argument, ungated: only a
  numeric derivative distinguishes it from a dropped `d/dz` channel, and V1 is that instrument.
- **The leaf's derivative is exactly zero by construction and declared.** Every output enters the active
  chain at one expression, which is where P3.2's supplied partials attach.
- **The reused tape is demonstrated, not realised.** No consumer holds one; calling the tape-less
  overload inside the cohort loop restores the old cost with nothing failing.

**Owed, small:** two `*it++ = <active>` R-boundary seams in `individual.h` and `stochastic_node.h`; a
`StochasticPatch` instantiation in the probe so those containers have a standing gate; and the mutant
replay path's tests, which throw because nothing has populated `environment_history` since odelia removed
the hook that called `cache_ode_step` — dead mechanism, live test.

### What Phase 3 has taught about gates, which is most of what it has taught

Six packets, and **every one found a real defect in its brief.** The defects were not varied: five were
one mistake in different costumes, and it is worth naming precisely because §0.6 does not catch it.

**A gate must name the quantity that moves when the feared thing happens — not the quantity you are
thinking about.**

| the gate | what it could not see |
|---|---|
| `template class TF24_Strategy<active>` as the active-build census | never instantiates `Individual`, so it was blind to the container holding the state the block differentiates |
| a reused tape's adjoints against a single call's | `newRecording()` leaves adjoints **correct** while leaking a slot per input per call; the discriminator was the recording *size* |
| an FF16/K93 tripwire written without `add_strategies` | both models ran empty and it printed no numbers at all |
| a type assertion that the transport probe returns `S` | **passes with the inner lambda at `-> double`**, because the quotient deduces its result from the point, not the integrand |
| "no errors in `resource_spline.h`" | measured through the type being changed rather than the type that consumes it |

Three rules come out of it, in increasing order of how much they cost to learn:

1. **Run the gate on the unmodified tree first** and confirm it produces a number you recognise. Kills the
   first three in ten seconds each.
2. **Census from the outermost consumer inward.** A strategy-level probe cannot see the container; a
   container-level one cannot see the R boundary above it. Five for five this phase — the last instance
   found the *entire light channel* silently passivated, 65 knot values and 65 slopes, invisible from one
   level down.
3. **When the failure is a derivative reading zero, the gate has to be a derivative** — and where that is
   not yet available, **constrain the callee instead of asserting at the call**. A `requires` clause finds
   every site; an assertion finds the site you thought of. That is what turned the failed transport gate
   into `integrand_of`, and it is what would have caught the light channel.

**Wave 1 makes it six packets for six**, and its three were one mistake in three costumes: **I asserted
that something was reachable, gated, or a type-widening, without compiling the thing that would have
said otherwise.**

| what I asserted | what compiling said |
|---|---|
| the standing probe gates the containers it names | a class-template instantiation does not instantiate member templates, so three `Individual` serialisers were gated by nothing |
| `stochastic_patch.h` is missing one name, 27 errors | 82 errors and three names, from a translation unit that includes it first |
| the 17 DeepCrown sites are a scalar widening | `Leaf` is untemplated and DeepCrown launders its crown means back through it, so it is a data-flow relocation into P3.2's seam |

Two further rules the wave earned, beyond §0's two. **A missing-include measurement carries its include
order** — the same shape as "a measurement carries its configuration", in a place the rule had not been
applied. And **an aggregate can quietly stop being a count**: `grep -c` over compiler output undercounts
as soon as `-fmax-errors` bails, so read the raw error list.

**And the cross-model tripwire's power is concentrated in one model.** K93 returns the identical value
under both configurations that wave 1 mixed up, so only FF16 caught the error — as in Phase 0, where FF16
alone caught the offspring-to-zero regression. **K93 is not a discriminating arm.** Worth knowing before
anyone drops an arm for cost.

---

## Where Phase 2 left things

**The phase is closed.** `p2/phase-2` (plant, `5fd351e9`, pushed) carries **P2.7, P2.1, P2.2, P2.6
and P2.3**, fourteen commits off `p1/audit-fixes`. P2.5 is a measurement and is answered. **P2.4 is
out of scope** — not deferred work — with `docs/reports/10-density-transport-and-carried-physiology.md`
as its home and the code preserved on plant `transport/cohort-grid-stencil`. Six tasks; three of them
move a forward number.

    derivs(y, t) twice, bitwise:  TF24 0 of 1137   FF16 0 of 686   K93 0 of 490

| | offspring | accepted steps | shift |
|---|---|---|---|
| plant `p1/audit-fixes`, before the phase | `42.176246845059751` | 5 105 | — |
| **`p2/phase-2`, everything merged** | **`42.179817344974609`** | **4 798** | **+0.0085%** |
| FF16 | `19.834058960443031` | 209 | +0.043% |
| K93 | `0.030538172107758225` | 240 | −0.028% |

Three value-movers composing to under a twentieth of a percent, with both simpler models holding
their exact step counts — so their figures are the change itself rather than the controller
re-rolling. Suite **1 309 pass, 0 fail**, plus one environmental error (`FF16_generate_stand_report`
needs pandoc). The evidence, gate by gate, is `implementation-notes.md` under *Phase 2*; the
per-item commits are tagged in `build-plan.md`'s Phase 2 preamble.

**The superproject pointer moves to this branch**, because the phase is closed and the re-blessing
is done. It stayed at Phase 1 while ten assertions were awaiting one pass, and pointing at it then
would have said otherwise.

### What Phase 3 inherits, and one item is load-bearing

- **P3.5's transport adjoint is the sub-grid probe's, not the cohort grid's.** `log_density_dt` reads
  `g` at the cohort's height *and* at `h − node_gradient_eps`, and the second is the output of a
  second evaluation of the block at a different input — so `lambda_g` stops being a closed-form seed
  and the reverse pass needs **two block recordings and two sweeps per cohort per stage**. Budget
  §8b's record-and-sweep term at twice its stated value, and **design this before P3.2 fixes the
  block's boundary**, not after. Report 10 §6.
- **A stage is now a pure function of `(y, t)`, bitwise, at all three models.** That is what P1.4's
  one-state-per-step store and P3.5's stage rebuild rest on, and it needed both P2.7's reordering and
  P2.1's fixed fractions — neither alone was sufficient.
- **The light field's input count is now fixed at 65 knot values and 65 slopes**, so §2.3's `141 + n`
  is well defined and T4's size assertion is statable.
- **The polished collar operating point is a stationary point** (`|R|` worst 9.587e-09), which is
  what makes P3.2's envelope row valid.
- ~~**Every production-like leaf state sampled came back pinned.**~~ **Measured in Phase 3 and
  settled: 0 pinned of 7 353 330** at the production driver, with a dry arm returning 990 724 so the
  zero is not a dead counter. The bound branch is insurance; the interior envelope case is the path.
  What the census added instead is that **80.9% of solves exhaust five Newton steps at `|R|` up to
  1.0019e-06**, so P3.2's envelope row budgets against 1e-6 and not against P2.6's 1e-13.

### Carried in, not covered by any task, and the owner's

- **`max(S, 0)` on storage is a derivative discontinuity active on 13.96% of records, and no task
  fixes it.** Storage genuinely goes negative (min −2.249e-03 against a median 1.756e-04), and
  develop's own comment claiming the outflow gate floors it at zero does not hold. The clamp zeroes
  the carbon → mortality → survival → density channel on all 14%, which is squarely on every census
  metric's gradient. Phase 2 was the re-blessing window and it did not ride; it now waits for the
  next one.
- **The establishment gate** and **the double-counted photosynthetic-nitrogen respiration** — both
  P0.6, both the owner's, both wanting a `scientific_version` bump.
- **`aornugent/plant#69`** — the transport term. Report 10 is the account.
- **Aux has two owners**: the operating-point transfer and the diagnostics a user reads. A functional
  reading `E_up_` through aux would give the cohort block a seventh output row.
- ~~**Report 02's zero pinned-leaf count predates P0.1, P0.2 and P0.12.**~~ Re-measured in Phase 3 and
  it holds; report 02 §4 now carries the confirmation and the two caveats on it.

### Owed, recorded rather than done

Each was deliberately not taken, and the reason is worth keeping in each case.

- **A newborn should probably inherit the boundary condition in the completed field A**, not in A0
  which excludes the boundary interval. A recruiting cohort does shade its own crown, and unlike the
  field build itself that is not circular. It is a modelling change, and a re-blessing pass is the
  wrong place for one. The 1e-21 `test-patch.R` assertion relaxed with a comment is what it would
  restore.
- **`hermite_interpolator` has no accessor for its knot values or slopes**, so `r_get_state` reads
  them back through `value_and_slope` and a slope returns as `fl(fl(m·h)·fl(1/h))` — up to an ulp
  from what was supplied. The fix belongs to odelia and would also let `spline` be R-facing again.
- **`ResourceSpline`'s dead constructor arguments** now select nothing.
- **`dR_dcollar` could be reused across the second Newton step** (7 evaluations per solve to 5). The
  first thing to try if the forward benchmark ever refuses the polish.

### What the phase taught about running one, beyond the tasks

- **A mean and an sd are the wrong summary for a quantity whose effect is set by its tail.** M4 read
  as a modest perturbation at mean −0.062, sd 1.878; its own census recorded a max of 142.85 against
  the sub-grid's 1.51, and that tail drove a 10.3× move. The census held both numbers and the packet
  was briefed on the wrong one — by me.
- **A packet boundary can manufacture a regression.** P2.6 step (1) without step (2) is +42% per
  step; with it, −1%. The plan's insistence that the value-movers land together is why.
- **A test that can no longer express its subject is not a moved baseline.** `spline$size` returning
  NULL is a renamed accessor; `spline <- interpolator` erroring is a capability gone. Reading the
  second as the first shipped a segfault and a lost R capability into a re-blessing pass, and both
  were missed because `test-scm.R` and `test-environment.R` were not in the gate list I wrote.
  **Name the files whose subject the change removes, not only the files it moves numbers in.**
- **Two packets caught stale premises in their own briefs** — a reference number from before a commit
  the tree already carried, and an instruction to remove code this corpus records as wrongly removed.
  §2.9's "its own baseline first" caught the first; reading the notes caught the second.
- **Test a property, not a configuration.** P2.6's bracket-independence test gated a changed default
  without being touched, because it was written against the residual. My own derivs-twice gate was
  vacuous for P2.1 for the mirror-image reason: `rescale_spline`'s remap is by exactly 1 when one
  state is evaluated twice, so the probe measured idempotence and never history independence.
- **Editing a worktree while it is building silently relabels which arm you measured.** Same family
  as the mid-write `.so`.
- **Function-pointer identity is not a discriminator** in a header-inline codebase without LTO: the
  weak-symbol addresses did not merge across translation units. A stored enum replaced it.
- **Name the arm a ratio is against, every time.** I reported the phase as faster than baseline by
  quoting it against P2.7's 24.3 ms/step rather than the pre-phase 22.76. §8b already insists every
  timing gate is a ratio measured in one session; what this adds is that the *denominator* has to be
  named as carefully as the numerator. And this session's wall clocks for comparable trees ran 97 s
  to 164 s depending on build contention, so **no phase-level ms/step is quotable from them at all** —
  only each packet's own same-session ratio.
- **A phase does fit one turn, and what makes it fit is the build count.** Six tasks landed on about
  a dozen builds because the writing fanned out and the building was serial (§4). The two things that
  cost extra builds were both mine: a gate that could not pass as written, and a gate list that
  omitted two files.

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
- ~~**`ResourceSpline<S>` promises an active height its interpolant cannot accept.**~~ **Closed by
  P2.3**: the Hermite is the evaluator and carries the active-position read.
- **`Solver::run()` serves two operations through one door** — a recorded trajectory and a
  caller-supplied time grid — and the vector alone does not say which. Two entry points are owed.
  These are not superseded stubs: the three `Solver_*` entry points were introduced in the same
  commit as `compute_jacobian` as one deliberate layering, and that commit retired the actual spike.
- **`ARCHITECTURE.md`** is still silent on this phase. *(The second half of this item — that the
  hermite lacked its pair of query readings — was checked against the tree and is false: it has the
  `set_nodes`/`set_data` split and the active-position read in both `eval` and `value_and_slope`,
  with a `static_assert` rejecting an active position against `S = double`.)*
- **`hermite_interpolator` has no accessor for its knot values or slopes** — added by Phase 2, and
  odelia's to fix. `plant`'s `r_get_state` reads them back through `value_and_slope`, so a slope
  returns as `fl(fl(m·h)·fl(1/h))`, up to an ulp from what was supplied.
