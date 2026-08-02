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

**A measurement carries its configuration — and so does a gate.** A gate seeded at hand-built or
fixture states is not a statement about production. Wave 2's collar-curvature gate was correct,
pointed at exactly the right quantity, and **did** register the defect — at 1.06e-05 among neighbours
reading 1e-11 — but at its hand-built states the defect is **1700× smaller** than at a state the
model visits, and a one-order outlier among 1e-11 rows is the shape a reader dismisses. Third
instance this phase, after P2.6's `|R|` gate passing on the test fixture's leaf and failing in
production, and wave 1's FF16 configuration false alarm. **Seed a gate at a state the model visits,
and say which state it was seeded at.**

**A gate's configuration must be committed, not merely recorded.** V1's number, its readout and its
discrimination were all written down, and its state and its seed were in an uncommitted R driver — so
the phase's headline verification was not re-runnable by anybody, and `2.32e-12` had to be retracted.
Prose does not satisfy "a measurement carries its configuration": **the configuration has to be a file
in the tree**. Fourth instance of that rule this phase, and the first on a headline number. Every gate
harness in `plant/scratch/` now has its build recipe committed beside it, and the V1 and V4 drivers are
in `plant/scripts/`.

**A suite count carries its invocation.** One packet measured 2 857 where two others measured 2 924 on
the same tree, because `load_package = "none"` over a `pkgload::load_all` tree makes several test files
take the `is_pkgload_dll_plant()` skip branch. So "2 924" is a number **plus a way of loading**, and a
count handed to a packet without one is the same defect as a baseline handed without its SHA.

**State the definition of a relative error alongside it.** One packet used `|a-b|/|b|` throughout while
the corpus's other numbers use `|a-b|/max(|a|,|b|)`. Under the first, "rel 1" means *a is negligible
against b*; under the second it means one side is exactly zero. **Two different diagnoses out of one
number**, and this phase has spent itself on the difference between "small" and "exactly zero".

**A census reaches only what it names.** Explicit instantiation of a class template instantiates its
**non-template members only**, and odr-use from a container reaches only the members it calls. So a
member template is gated only by naming it. Wave 1 found three ungated seams that way —
`Individual`'s three iterator serialisers — and one of my own standing probes was blind to the very
packet it was gating. "Census from the outermost consumer inward" is necessary and not sufficient;
name the member templates explicitly.

**A gate can fail because its reference is not differentiable, and the tell is the absence of a
plateau.** V3 looked like a four-order missing term on one row and was five entries of a
non-Lipschitz `y_end`: `sqrt(62.42² + 13.78² + 45.07² + 29.84² + 32.70²) = 89.87`, five numbers
that mean nothing. **Before believing a disagreement, sweep the difference step and look for a
plateau.** A bad reference *improves* as the step grows while a clean row degrades — that much the
corpus already carried — and the stronger reading is the one wave 4 measured: **no plateau at all
means the reference and not the subject.** With the reference repaired all 64 rows closed with
nothing excluded and no tolerance widened.

**A tolerance that was loosened for speed can make a model non-differentiable.** P2.6 loosened
`GSS_tol_abs` to 1e-1 on a measurement that the collar polish made the answer bracket-independent
to 1.044e-09 — true, and true only on the 24.7% of solves that converge; the other three-quarters
exhaust a five-iteration cap. The spread of one step's `y_end` over 1e-5 input displacements is
1.141e-03 at production against 1.586e-10 at `GSS_tol_abs = 1e-6`, where the true derivative is
9.21e-08, so the noise exceeded its own signal by nine orders. **Loosening an iterative tolerance
is safe for a value and can be fatal for a derivative, and the check is a jitter measurement
rather than a residual** — a residual is what passed here.

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
- **A mechanical sweep over every diff before it lands** — `scripts/build/style-sweep.sh <worktree>
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
- **No active value may outlive a recording.** `clearAll()` resets the tape's slot counter, so an
  active object held across the cohort loop aliases whatever takes its slot next. Measured: only the
  very first block of a run was correct, later blocks had most trait rows exactly zero and a few
  spuriously large, nothing thrown, and **V2 passed because its first call was the clean one.** The
  fix is a per-block copy from a never-recorded template.
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
suite. **V1 and V2 have since been built and taken** — their harnesses are named in §11.5 — and each
cost a wave's worth of instrument-building before it read a number. What remains is the same shape:
V3 needs `step_adjoint` driving plant; V4 needs a re-run finite difference at production lifetime,
which for 51 traits is **102 forward runs** — §8b is explicit that V4's verification is the expensive half of the
acceptance test rather than the cheap one.

So plan it as **several turns with one task each**, and treat the per-task V-check as the turn's product.
The thing that must not happen is a turn that lands two tasks and can attribute a V-failure to neither.
*Evidence that this is the right reading: the phase's prerequisites alone took six packets and about
fifteen builds, and none of them was one of the five tasks.*

### 11.2 The order, and where the phase is on it

```
    DONE  the prerequisites ── all landed, bit-identical, integrated
       |
    DONE  Patch::rebind_from ── the only route to an active Patch
       |
    DONE  Environment's cohort-reads triple ── n_cohort_reads/cohort_reads/set_cohort_reads,
       |                                      135 for TF24, so the five soil potentials
       |                                      are declared inputs rather than passive
       |
    DONE  P3.1  (a) soil ── (c) light knots ── (d) allometry, step (b) stubbed   V1 taken
       |
    DONE  P3.2  (1) block, leaf held ── (2) envelope + flux ── (3) the waist ──
       |        (4) translation      with V2, V2L, T4, T5, T6 taken
       |        (5) pinned           bound_partials by the implicit function theorem,
       |                             gated against a bisection at 2.13e-10 … 9.5e-09
       |
    DONE  P3.3  the leaf's own parameter rows ── fifteen filled, finiteness 0 of 28 /
       |        0 of 34 / 0 of 28 across four states
       |
    DONE  P3.5  the stencil's adjoint, driven from Step::step_adjoint    V3 taken, at a
       |          stated configuration. Merged into p3/wave4. All 64 rows close, worst
       |          1.36e-02 at node 2 slot 8, at GSS_tol_abs = 1e-6, node_gradient_eps =
       |          1e-3, fd_eps = 1e-7 (scripts/v3-driver.R). The recorded failure was
       |          reference noise: five entries of a non-Lipschitz y_end, not a term
       |
    DONE  P3.6  census<Psi>, the entry point, agents.md §13         V4 attempted and
                NOT takeable: the reference is computed and committed, and its
                difference does not converge in the step. §2.5's V4 is not achievable
                on this forward model as it stands
```

So the remaining work is **not a task**: V4 is blocked on a forward-model property, and what
remains is the owner's.
The state, with its numbers, is in "Where Phase 3 stands" below; the evidence is
`docs/implementation-notes.md`, *Phase 3, wave 1* and *Phase 3, wave 2*.

**P3.5's transport adjoint is designed and its premise was false**, which is the one correction inside the
task list worth carrying forward. Report 04 §5 says differentiating develop's sub-grid probe at an active
scalar yields the derivative of the discretisation actually solved: true of the scheme, false of the code,
which was passive at three points. The probe now carries the scalar and the quotient helpers refuse a
passive integrand. **The design to build: record both evaluations and let the tape form the quotient**, so
`lambda_g` needs no hand-written seed — two block recordings per cohort per stage, which is report 10 §6's
cost. **The block now exists and has been measured**, so that is a concrete cost against a measured block
rather than a projection: two recordings per cohort per stage of a `Patch::cohort_block_adjoint` whose
figures are in §11.4. The conditioning is inherited and is about `1e-10` absolute, so **gate that channel
against a finite difference of the same quotient, never against an analytic `dg/dh`**.

### 11.3 The gates: six taken, and the seventh has no valid instrument

§0.5 and §0.6, applied before anything is sent. Every reading below is in
`docs/implementation-notes.md`, *Phase 3, wave 2*; what is here is what each gate turned out to be.

**Taken.** Several of the traps fired, and what happened is more use than the warning was.

| | what it measured | what the trap did |
|---|---|---|
| V1 | steps (a), (c), (d) plus the blocks against one whole-`Patch` recording at one state. **Wave 2's `2.32e-12` is retracted** — not reproducible, and its configuration was never committed. Re-established on the strategy columns, seed six strategy-rate slots per node, at `scripts/v1-driver.R`: **normwise 3.33e-15 and pointwise 2.05e-11 at lifetime 2**, 1.56e-16 at 0.5, 7.35e-12 at 3, 4.30e-09 at 20 | fired exactly as written. **(a) alone reads rel 1**, because the accumulator is nonzero before the blocks arrive, so only adding the contributions one at a time localises it. And **V1 as originally specified was not achievable**: the recording has no soil channel (the soil store is a declared passive boundary) and it carries the transport stencil the decomposition omits until P3.5. **The exclusion is seed-side *and* comparison-side** — seeding only the strategy rows removes rows and not columns, so a residual over all components is pinned at exactly 1 at every state under every seed, which is what two packets independently hit. Normwise is the headline, pointwise printed beside it. V1 degrades with lifetime, so it is a decomposition check at short lifetime and says nothing about production |
| V2 | one cohort's block against a finite difference of the same block, leaf held, stage 0 — **six strategy rates 7.9e-14 … 2.2e-07, five uptake outputs 1.6e-09 … 3.7e-07** | the uptake rows first read **2.0e-02**, and that was a real defect and not the reference: `dR_dcollar_` published a step-stale divisor, a uniform 2% on every uptake row. Stage 0 remains the limit — a block lives at a stage and stage states are rebuilt, which is V3's subject |
| V2L | report 02 §6.9's three identities, all passing | and the limitation the phase discovered: **§6.9's stationarity identity cannot discriminate a wrong `Π_pp`**, because `dp*/du` is formed from it. The real 2% defect above passed it at **4.54e-10, bit-for-bit unchanged before and after the fix.** It remains right that a re-run finite difference cannot referee the leaf; what is new is that this identity cannot referee `Π_pp` either |
| T4 | the size identity and the pack/unpack round trip | caught the real thing, twice: bypassing `set_state` leaves the dependent aux stale, **and** the parameters must be seeded *before* the states, because `area_leaf(height)` reads `lma` and the rule as written did not say so |
| T5 | knot-adjoint accumulation, asserted as a value — **exact over all 65 knots**, and `=` for `+=` moves 55 of 65 | but it was **ungateable at P3.2 step (1)**: the light channel into a cohort is 100% leaf-mediated — of 130 knot entries, 13 move an output, 13 move the leaf, 0 move an output without the leaf — so `lambda_knot` was identically zero by construction until the leaf partials were wired. A step gated on it was gated on nothing. **And wave 3 did not reproduce it** — the same cause as V1's retraction, an uncommitted harness configuration. Recorded as a non-reproduction rather than a refutation; the accumulation itself is unchanged, and re-running it needs the configuration written into the tree first |
| T6 | trait-adjoint accumulation, asserted as a value — passes | the discrimination is there: `=` for `+=` gives **0 of 21 rows agreeing**, ratios 0.0009 to 0.9859, the sign right on most of them and nothing thrown |

**V3 taken, V4 not takeable.**

| | gate | where it stands |
|---|---|---|
| V3 | one step's `lambda_y` against a finite difference of one step | **taken in wave 4, at a stated configuration**, and merged into `p3/wave4`. All 64 rows close normwise with nothing excluded and no tolerance widened, worst **1.36e-02 at `node 2 slot 8`**, at `scripts/v3-driver.R`'s pinned reference configuration: `GSS_tol_abs = 1e-6`, `node_gradient_eps = 1e-3`, `fd_eps = 1e-7`. Wave 3's failure was **entirely reference noise** — at production `Control()` the collar bracket makes one step's `y_end` non-Lipschitz at the difference scale, and the `89.875` that looked like a missing term is five such entries, `sqrt(62.42² + 13.78² + 45.07² + 29.84² + 32.70²)`. **Two limitations beside the pass, not underneath it**: `node_gradient_eps = 1e-3` is the sub-grid probe's own discretisation and not a harness knob, so V3 verifies the transpose of a slightly different operator than production runs; and 1.36e-02 is loose next to V1's 3.33e-15 — reference-limited, the non-transport floor being 1.26e-03 at the same step in every configuration tried, which does not prove the row carries no adjoint error |
| V4 | census and R0 at `max_patch_lifetime = 105.32` against a re-run FD, under 2 GB peak | **attempted in wave 4 and not takeable, and the reason is measured.** The reference was computed in full and committed — nine traits × four outputs at relative step 1e-5, on plant `4f9bda64`, TF24 at `max_patch_lifetime = 105.32`, `lma = 0.1978791`, `Control()`, `refine_schedule = FALSE`, census at `t = 105.32`, 26 production runs all confirming 4 798 steps — as `scripts/v4-reference.rds`, `.csv` and `scripts/v4-reference.R`. At this lifetime the boundary node **is** live, density 4.737, so the reference does carry a boundary-node channel; what it cannot see is 6 of 95 cohorts at density exactly zero. **But the difference does not converge in the step**: `d(leaf_area)/d(lma)` reads -155.6, -9.356, -207.3, -35.19, -1424.6 at relative steps 1e-2 to 1e-6, non-monotone by factors of 5 to 40, with `psi_crit` changing sign between steps and the base bit-reproducible three times. **The reference cannot referee an adjoint to better than about 100% per entry.** Three obstructions: the step non-convergence itself; schedule pinning not self-consistent even at cap 5, shifting `leaf_area` by ~5e-4 relative and R0 by 0.24, so the one-sided arrays mix a free base against pinned arms; and the two halves of V4 pointed at different models — `scripts/v4-census-gradient.R` at `lma = 0.0825` with `refine_schedule()`, `scripts/v4-reference.R` at `lma = 0.1978791` pinned. Two candidate causes tested, **neither supported**: the collar staircase is **unconfirmed rather than refuted** (the cap-20 sweep invalidated itself — a `h = 0` control collapsed 210 orders with zero perturbation, so it measured a pinning artefact), and the establishment gate is **excluded at `h = 1e-5`** by a node-level proxy, the zero-establishment set identical across base and both arms and the one surviving in-window node smooth in `lma`. **So §2.5's V4 — a whole-run gradient against a re-run finite difference at production `Control()` — is not achievable on this forward model as it stands** |

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

**The block has since been measured, and it cuts against the record-and-sweep term above.** One
`Patch::cohort_block_adjoint` call is **65 µs against 31 µs for one forward `compute_rates`, 2.1×**, of
which per-block template copies are 12.7 µs. And the tape-less overload costs only **1.19×** here rather
than the corpus's 10.2× marginal / 5.56× at the block's size, **because this block is dominated by the leaf
solve rather than by recorded arithmetic**. So §8b's multiplier is a multiplier on recorded arithmetic and
the block is not that. **The total above wants re-costing against these figures.** It is not refuted — 2.1×
measured against a term budgeted at 5.56× is not a margin either, because the terms are not the same
quantity — but it is no longer derived from the right one, and re-deriving the sum is work somebody owes.
Measurements in `docs/implementation-notes.md`, *Phase 3, wave 2*, *Measured cost*.

The reused tape is now **realised**, in wave 2's cohort loop, and it brought §10's hazard with it: no
active value may outlive a recording.

### 11.5 How to run a wave here

Operational facts two waves accumulated that the plan does not carry.

- **The in-flight gate is the active-instantiation probe, `plant/scripts/tf24-active-probe.cpp`.** It
  reads **2** on the current tip, both `prepare_strategy` / `height_seed` `static_assert`s, and any other
  number is the finding. It costs about **7 s**; a full build here is about **ten minutes**, so the probe
  is what a packet closes on and a build is what integration pays for.
- **odelia is already installed and verified at `/home/user/lib-p3-int`.** Packets read it **read-only and
  install nothing**. That removed an entire class of failure across two waves, and §5's per-packet library
  applies only to a packet that changes odelia.
- **The build and gate assets are committed at `scripts/build/`**, with a `README.md` giving the
  pinned build's recipe and the two greps that confirm it took: `Makevars-O2` (the flags every value
  gate in this project is stated against), `style-sweep.sh` (§7's mechanical pass) and `ff16k93.R`
  (the FF16/K93 tripwire). All three previously lived only in a container home directory and were
  lost whenever it was reclaimed, while the corpus cited them by absolute path.
- **`ff16k93.R` hardcoded a Phase 0 worktree** (`/home/user/wt-canopy-shape`), so it was already
  broken before it moved. It now takes the plant worktree as its first argument —
  `Rscript scripts/build/ff16k93.R <plant worktree> [tag]` — and **every model parameter is
  unchanged**: the per-model trait, the per-model hyperpar, the default lifetime and
  `sum(offspring_production)`. Only the path handling moved, so the reference numbers it prints
  still belong to the configuration below.
- **The three models use three different configurations, and mixing them cost a false alarm.** TF24 at
  `lma = 0.1978791` with `max_patch_lifetime = 105.32`; FF16 and K93 at `scripts/build/ff16k93.R`'s
  settings — its own per-model trait *and* hyperpar, the default lifetime, and
  `sum(offspring_production)`. **FF16 is the only discriminating arm**: K93 returns the same value under
  either configuration.
- **The V1, T5 and V2 harnesses are committed** under `plant/scratch/`, so those gates are re-runnable
  rather than needing rebuilding, and it is one file of the two:
  **`plant/scratch/wire_gates.cpp` holds all three** — the decomposition against one whole-`Patch`
  recording one contribution at a time (V1), one cohort's block against a finite difference of the
  same block (V2), and the per-cohort knot contributions against their sum (T5) — plus the collar
  residual and curvature probes. **`plant/scratch/leaf_jac_gate.cpp` is the leaf's own gates**,
  standalone against `Leaf::input_adjoints`: stationarity, continuity, the waist, the translation
  partials, the `inputs()`/`input_adjoints` size identity and `FULLSOLVE`. Neither file holds T6;
  its harness was the `p3/cohort-block` packet's and is not in the tree.
  (Both belong in `scripts/` beside the probe, which is owed.)
- **Both harnesses' build recipes are now recorded**, in `plant/scratch/README.md`. They were not,
  and the earlier claim here that they were re-runnable was false: every gate in `wire_gates.cpp`
  is an `[[Rcpp::export]]` taking the patch as a `SEXP`, so the state, the seed and the readout
  lived in an R driver nobody committed, and V1's headline number could not be re-run by anybody.
  That driver is now `plant/scripts/v1-driver.R`, taking the plant worktree as its first argument
  — `Rscript scripts/v1-driver.R <plant worktree> [max_patch_lifetime]`. **A gate's configuration
  must be a file in the tree, not a paragraph.**
- **`plant/scripts/v3-driver.R` is V3's harness**, taking the plant worktree as its first
  argument, with a second argument sweeping the difference step instead of printing the 64-row
  table. **Its two loosened-from-default `Control` values belong to the reference and not to the
  adjoint**, and the file says why: `GSS_tol_abs = 1e-6` and `node_gradient_eps = 1e-3`. Both are
  forward settings, so the adjoint and the difference are taken at the same operator.
- **`plant/scripts/v4-census-gradient.R` is V4's harness**, written and unrun; its subset and its
  refusals are in §11.3. **`plant/scripts/v4-reference.R` is the other half** — the re-run finite
  difference — with its computed reference committed beside it as `scripts/v4-reference.rds` and
  `scripts/v4-reference.csv`, each carrying its full configuration. **The two halves are pointed
  at different models** (§11.3) and reconciling them is the first thing anyone re-attempting V4
  owes.
- **One worktree and one branch per packet**, and **the verification worktree must not be one anything has
  been experimenting in** (§5).

### 11.6 The documents the plan assigns, and Phase 1 missed one

§9's "some work has no packet, and it is the integrator's". Every Phase 1 allowlist was code and tests, so
nothing updated `odelia/AUTODIFF.md` — which the plan makes the home for the System requirements that phase
*changed*. Check each before closing the phase:

Each was checked against the tree in wave 4, not against the last record of it.

| document | what Phase 3 owes it |
|---|---|
| `odelia/AUTODIFF.md` | **`ode_rates_adjoint` and `AdjointRates` landed in wave 4**, under *Carrying your own rate transpose* in the System contract, with `set_ode_state_and_field`, the aux family's role, the `if constexpr` choice, the RODAS refusal and `Solver::solve_adjoint`. **Phase 1's arrears are still open**: `active_scalar` and `Rebindable` are named nowhere in the file, and `Rebindable` is what the default branch's `static_assert` fires on, so a reader who hits that error has no document to go to |
| `odelia/ARCHITECTURE.md` | **still silent on the `Tape` link as this build uses it**, and wave 4 widens the gap: the tape is now created inside `step_adjoint`'s default branch and destroyed with the stage loop, which is the lifetime §10's hazard is about. Unowed by any packet and still nobody's |
| `plant/agents.md` §13 | **landed in wave 3** and holds — a fourth census metric is 14 lines in one file, no tape code, no odelia, a 40-second rebuild. Nothing owed |
| `plant/NEWS.md` | **`stand_gradient` is there**, with the `Control` it records and `stand_gradient_compare`. What is **not** there is P3.5: `Patch::set_ode_state_and_field` and the transport term becoming a block output are internal, so nothing breaks, but the polish-cap finding below is the kind of thing NEWS is read for and it is not an entry because nothing was changed |

### 11.7 Carried in, and none of it is Phase 3's to decide

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

**Everything is built, and everything is verified for which a valid instrument exists. The phase
does not close.** All five tasks are written and merged, six of the seven gates are taken, and
**V4 is blocked on a property of the forward model rather than on any part of this build** — a
re-run finite difference at production `Control()` does not converge in its step, so §2.5's V4
has no reference. There is a **named one-line candidate fix and it belongs to the owner**:
`Leaf::polish_root_collar_psi`'s `max_iter = 5`.

    plant   p3/wave4               wave 4: P3.5 + the V4 reference half
    odelia  p3/odelia-integration  wave 4: p3/stepadj merged, first move since fdccd7b

The superproject pointer moved in `6b5238b` for wave 1, `f486ce9` for wave 2, again for wave 3
and again for wave 4, staged alone each time. Wave 4 merged two branches into `p3/wave4` off
plant `4f9bda64` with **zero conflicts**: 12 files, 1 876 insertions, 36 deletions, and the
insertion arithmetic closes exactly — 1 658 + 218 = 1 876. Odelia's merge is 5 files, 498
insertions, 75 deletions, identical to `git diff fdccd7b 6734260` to the line.

**The whole phase is still bit-identical.** TF24 `42.179817344974609` / 4 798 at TF24's own
configuration (`max_patch_lifetime = 105.32`, `lma = 0.1978791`, `Control()`,
`refine_schedule = FALSE`); FF16 `19.834058960443031` / 209 and K93 `0.030538172107758225` / 240
via `scripts/build/ff16k93.R` at its own configuration; `derivs(y, t)` twice bitwise pure, 0 of
1 137 at the production patch; the standing probe at 2, both `tf24_strategy.h` static assertions.
odelia **346 / 0 / 2** — 334 + 12 from `p3/stepadj`. `xad::` and `const_cast` both empty on the
merge, and the style sweep's six candidates are all comments the diff moved or hazards the rule
exempts.

**plant reads 2 877 / 0 / 6 / 10, and the recorded 2 944 is a non-reproduction rather than a
regression.** Under `library(odelia)`, `pkgload::load_all(worktree)`, then
`testthat::test_dir(dir, package = "plant", load_package = "source")`, the merged tree and
`4f9bda64` read the **same** 2 877 / 0 / 6 / 10 — from separate worktrees and separate libraries
— which is what the gate is for, since `p3/stepadj` adds no plant tests. The gap is 67, the same
67 that separates the corpus's 2 924 from its 2 857, and the skip count is 10 either way, so the
three `is_pkgload_dll_plant()` files are not where it lives. **A suite count carries its
invocation** and 2 944 was recorded without one. Third non-reproduction of a recorded number this
phase, after V1's `2.32e-12` and T5, with the same cause each time.

**What remains, and none of it is a task.** In priority order, for the next session:

1. **Put the polish cap to the owner.** `Leaf::polish_root_collar_psi` carries
   `R_tol = 1e-11, max_iter = 5`, and at production `Control()` **75.3% of 2 206 526 solves
   exhaust the cap** rather than converging, exiting at `|R|` up to 9.9986e-07 against 2.07e-12
   for the quarter that converge. Cap 20 takes the one-step non-smooth residual spread from
   7.820e-05 to 8.626e-08 and the exhausted fraction to 5.05%; **tightening the bracket instead
   reaches the same floor, 6.192e-08, from an independent direction**, which makes it a mechanism
   and not a correlate. It moves forward numbers — offspring 42.411799695604159 / 4 644 at cap 20,
   42.440891828033472 / 4 683 at cap 100, against 42.179817344974609 / 4 798 — so it needs a
   re-bless, and it carries a `scientific_version` question this phase does not decide: a
   convergence cap is numerics, but a model that does not solve its own stated optimisation on
   three-quarters of calls is arguably a correctness fix. **It also qualifies a committed
   claim**: P2.6's bracket-independence to 1.044e-09 holds on the 24.7% that converge.
2. **Reconcile the two halves of V4 onto one configuration.**
   `scripts/v4-census-gradient.R` builds its stand at `lma = 0.0825` and calls
   `refine_schedule()`; `scripts/v4-reference.R` uses `lma = 0.1978791` with the schedule pinned
   and no refinement. Neither half can be believed against the other until they name the same
   model. **A harness brief that does not state the model configuration is the defect** and it
   was mine.
3. **Resolve the schedule-pinning inconsistency.** Pinning the base run's own schedule and
   `ode_times` shifts `leaf_area` by ~5e-4 relative and R0 by 0.24 **at cap 5**, so
   `run_on_schedule` is not self-consistent with its own base. The committed reference's central
   differences survive this because both arms are pinned identically; its one-sided arrays mix a
   free base against pinned arms and are suspect, and an adjoint taken on the free trajectory is a
   fourth way for the two halves to compare different models.
4. **Rebase `p0.5-instrumentation.patch`.** It targets develop `141dc8df` and expects
   `src/tf24_strategy.cpp`, which does not exist here; `node.h`, `patch.h`, `species.h` and
   `leaf_model.cpp` all fail. Recovered as an asset in `02bfc4e`. **A recovered asset that cannot
   be applied is not an asset**, and it was being counted as a gate arm.
5. **Then re-attempt V4**, and not before 1–3. The reference is computed and committed
   (`scripts/v4-reference.rds`, `.csv`, `scripts/v4-reference.R`, with its configuration) and its
   step non-convergence is measured: `d(leaf_area)/d(lma)` reads -155.6, -9.356, -207.3, -35.19,
   -1424.6 at relative steps 1e-2 to 1e-6, `psi_crit` changing sign between steps, the base
   bit-reproducible three times. Only `lma` and `psi_crit` were step-checked; **assume the other
   seven are equally unconverged until checked.** The two candidate causes stand as: the collar
   staircase **unconfirmed rather than refuted** — the cap-20 sweep invalidated itself, its `h = 0`
   control collapsing 210 orders with zero perturbation — and the establishment gate **excluded at
   `h = 1e-5`** by a node-level proxy, not at 1e-4 or 1e-6 and not against the 23.1%
   stage-evaluation count.

Carried in from earlier and still the owner's: the `mortality = Inf` treatment, which changes the
census **value** by up to 6.19e-06 relative at lifetime 12 and by exactly 0 at lifetime 20 — the
latter only because that state's dead set is contiguous at the bottom — and the
vulnerability-integral knot count below.

**What wave 4 added.** P3.5 merged and V3 taken at a stated configuration: all 64 rows close
normwise with nothing excluded and no tolerance widened, worst **1.36e-02 at node 2 slot 8** at
`GSS_tol_abs = 1e-6`, `node_gradient_eps = 1e-3`, `fd_eps = 1e-7`, committed in
`scripts/v3-driver.R`. **Wave 3's failure was entirely reference noise**: at production
`Control()` the collar bracket makes one step's `y_end` non-Lipschitz at the difference scale —
spread 1.141e-03 against 1.586e-10 at `GSS_tol_abs = 1e-6`, where the true derivative is
9.21e-08 — and the `89.874514855298955` that looked like a missing term four orders large is
exactly five such entries, `sqrt(62.42² + 13.78² + 45.07² + 29.84² + 32.70²) = 89.87`. Report 04
§5 predicted the staircase and nobody had connected it, because P2.6's polish was believed to
have removed it. The step sweep has a **plateau at 1e-08 to 3.16e-07 flat at 1.36e-02**, and at
production `Control()` the same sweep has **no plateau at all**, which is itself the signature
that the reference and not the adjoint was at fault. **Two limitations recorded beside the pass,
not underneath it** (§11.3). **Two earlier attributions were overturned by the packets that made
them**, both index errors rather than code errors, and **there is no pre-existing defect
underneath P3.5.**

**Three diagnostics in this wave overturned their own hypotheses** — the cap-20 sweep, node 2's
height column and the establishment-gate candidate. That is the wave's character rather than a
defect in it.

**And one file in the merge has no business in the tree.** `build.log`, 1 177 lines, committed on
plant `4fff1e22` and carried in. The style sweep's generated-files category does not name it, and
the pinned build recipe writes over it, so a verification build leaves the tree dirty against a
file nobody meant to track. Not removed in wave 4 — nothing in the wave required it.

**What wave 3 added.** P3.3 and P3.2 step (5): fifteen leaf parameter rows plus the bound
rows, finiteness from 15 of 28 and 34 of 34 non-finite down to **0 of 28 / 0 of 34 / 0 of
28** across four states, profit rows against a whole-solve central difference at 1e-6 to
4e-10 and bound rows against a tight bisection at 2.13e-10 to 9.5e-09. P3.6: `Species::census`
from the boundary node, `namespace census_metric`, `[[Rcpp::export]]` free functions typed to
TF24, `stand_gradient` recording the `Control` it differentiated at, `agents.md` §13 and
NEWS. The census agrees with an independent R reduction of TF24's allometry at 1e-12, and
**the quadrature-weight term is 101.3% of the total with the integrand-only derivative of the
opposite sign** — report 00 §6.3 called it the term most likely to be dropped by hand, and
dropping it flips the answer rather than shrinking it. §13's acceptance test holds: a fourth
metric is 14 lines in one file, no tape code, no odelia, a 40-second rebuild.

**V1's `2.32e-12` is retracted, and V1 is re-established.** The number is not reproducible and
its configuration was never committed; two packets independently failed to reproduce it. The
cause was the comparison rather than the code — seeding only the strategy rows removes rows of
the Jacobian and not columns, so a residual over all components is pinned at exactly 1 at
every state under every seed. Re-established on the strategy columns at
`plant/scripts/v1-driver.R`: **normwise 3.33e-15, pointwise 2.05e-11, at lifetime 2**, with
normwise the headline and pointwise printed beside it. `(d) + allometry` buys eleven orders at
every state measured, so the incremental readout's attribution stands. The layout is also
corrected: `Patch::ode_state` writes **species first, environment last**, so the 9 environment
slots are trailing — `node = index0 / 8`, `slot = index0 % 8`, environment iff
`index0 >= 8 * node_count`. Two packets and I had that backwards.

**One finding of the wave, and it invalidates a committed number.**
`build_cumulative_vulnerability_integral` sets `psi_max = b*log(100)^(1/c)` and
`step = psi_max/resolution` under a `psi <= psi_max` loop bound, so **the knot count steps
between 100 and 101** as `b` or `root_b` moves by 1e-6 relative. Report 02 §6.4's premise —
control points fixed at construction, parameter carried by the values — is false in the tree.
Held grid against moving grid: `dR/d(root_b)` 3.541221 against 168.3776 (47x),
`d(profit)/d(root_b)` -2.2215 against -290.86 (131x), `d(bound_a)/d(root_b)` 1.68651 against
17279.08 (10245x); invisible at wet states and growing with drying. **The committed harness's
`WAIST-EXT` row, recorded in wave 2 as passing at rel 1.37e-04, is wrong by 47x on both
sides** and agrees only because both were built from the same poisoned pair — the second
instance this phase of a gate built out of the thing it is testing. **Ruling: hold the grid,
let the values carry the parameter**, which is what `agents.md` §13 and report 03 already
require. **But the forward model still carries the discontinuity**, so fixing it moves forward
numbers and is the owner's.

**A count discrepancy, recorded and not resolved.** `ad_parameter_names()` returns **44**. The
corpus says 51 (report 01 §4.2) and 55 for `ad_parameters()` (wave 1). §8b's cost model and its
~26x saving are computed from 51.

**Two rulings taken.** The knot grid stays fixed and passive — report 03 C1's reason, committed
at P2.1 — at a measured cost of about **87% of the tallest cohort's height adjoint**, with C1's
unmeasured convergence-with-knot-density still the falsifier, and V3's failing row may be that
same channel. And on P3.5's design, where two documents disagreed: **`build-plan.md`'s P3.5 is
the decision** — record both evaluations and let the tape form the quotient — while report 10
§6's two-sweep cost is a projection written before the design existed, and it contradicts
P3.5's own "step (a) loses one of its three sources".

**The cost model still reads ~430–460 s, 3.7 to 4.0 forward runs, a ~26x saving**, and it still
wants re-deriving against wave 2's measured block (§11.4) — now also against 44 traits rather
than 51.

**Owed out of wave 3, each with the reason it was not taken**, and none of it blocking:
`beta_R_H` and `beta_R_V` still have no row, so a strategy varying either reads **exactly
zero** — the last such hole in the leaf boundary, not taken because adding rows renumbers the
input vector, and cheap for whoever renumbers since they factor through the waist pair at 6e-10
to 3.5e-09; `bound_b`'s arm written and never exercised across 24 swept configurations, every
pinned state pinning at `bound_a`; the aux saving, transferred but unrealised because
`cohort_block_adjoint` still re-solves the leaf inside the recording; report 02 C3 firing live —
`set_physiology` keys the `vcmax_`/`jmax_` block on `(leaf_temp_, atm_o2_kpa_)` alone, which does
**not** block V4 because a re-run difference builds a fresh `Leaf`; the stationarity band
`4.5e-10 … 5.1e-09` never covering a row that reads 2.83e-10, which the base tree prints too, so a
corpus correction rather than a re-bless; `psi_crit` publishing 0 at a pinned state against a
whole-solve -2.39e-04, through `bound_b` into golden section's bracket; two of the three known-
stale comments still stale, with the corpus's description of the third itself half-stale; and
`dprofit_droot_collar_psi`'s NaN-kink fallback now inside every `∂R/∂θ` residual pair, incidence
uncounted.

**Owed out of wave 1 and wave 2, still open:** the `field_ptrs()` / `ad_parameters()`
unification onto one yml-ordered table; `prepare_strategy`'s `throw` becoming `util::stop`;
deep-crown restored as a differentiable arm; C1's convergence measurement; the cohort-reads
triple's pre-build state; `FF16_Strategy()$eta_c` printing nothing; `∂R/∂PPFD` and `∂R/∂κ`
carried as residual pairs; `Environment::cohort_reads`' `as_iterator_scalar` fix being TF24-only;
the two gate harnesses belonging in `scripts/` beside the probe; `have_dR` in
`polish_root_collar_psi`; odelia's `vector_jacobian_product` header not saying that no active
value may outlive a recording; two `*it++ = <active>` R-boundary seams in `individual.h` and
`stochastic_node.h`; a `StochasticPatch` instantiation in the probe; and the mutant replay path's
tests, which throw because nothing populates `environment_history`.

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

**Wave 2 continues the tally, and the tally is now the finding: every packet in this phase has found
a real defect in the orchestrator's brief.** Wave 2's were the nine-site count taken from a
stale comment rather than from report 02 §3.3, a V1 specified to compare two models that do not carry
the same channels, and a step (1) gated on a T5 that was vacuous by construction.

**Wave 3 makes it ten**, and two of its ten had consequences: I asserted that
`Step::step_adjoint` did not exist when it did — with the evidence sitting in my own handoff notes —
and I propagated a wrong index map that a packet then had to be corrected out of mid-flight.
`Patch::ode_state` writes species first and environment last.

**Wave 4 makes it fourteen**, and two of its four had consequences. I briefed the failing V3 row
as **the tallest cohort's and localised** — it was every row, and the localisation was an artefact
of the statistic that reported it. And I briefed a V4 harness **without stating the model
configuration**, so its two halves were built against different `lma` values, `0.0825` with
`refine_schedule()` against `0.1978791` pinned. The second is §0's "a measurement carries its
configuration" reaching a *specification* rather than a number: a harness brief that does not name
the model has not specified a harness.

**A plausible constant factor is worse than an exact zero.** This phase has spent itself guarding
against exactly-zero because a zero reads as an answer. Wave 2's `dR_dcollar_` defect was a **uniform
2%** on every uptake row: every entry finite, every sign right, the ratios stable across rows.
**A zero looks like nothing; 2% looks like a result**, and nothing in its shape asks to be looked at.

**And the four-instrument story, which is the sharpest thing the phase has produced about gates.**
Four instruments were pointed at that block and none stopped it:

| the instrument | why it did not discriminate |
|---|---|
| report 02 §6.9's stationarity identity | passed at 4.54e-10, **bit-for-bit the same before and after** — `dp*/du` is formed from `Π_pp`, so a wrong `Π_pp` cancels and the identity passes for the wrong reason |
| a finite difference of the leaf solve | cannot referee it, and **§2.5 says so correctly** — so a reader could have cited the corpus, accurately, to dismiss a real 2% |
| the reference-limit explanation I proposed | excluded by four to five orders: the two solves sit 1.75e-12 apart in residual where ~5e-9 would be needed |
| the `FULLSOLVE uptake0` gate | **correct, and pointed at the right quantity** — it read 1.06e-05 among neighbours at 1e-11 and was dismissed, because at its hand-built states the defect is 1700× smaller than at a state the model visits |

The second row is the one to carry forward. **A correct caveat is also a correct-sounding excuse**,
and a corpus that records why an instrument cannot referee a question has handed the next reader a
citation for ignoring the answer.

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
