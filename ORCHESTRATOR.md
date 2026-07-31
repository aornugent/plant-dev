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

**6. Ask what would make the gate pass vacuously.** An agent added a gate the orchestrator had not
thought of — `static_assert(Replayable<Patch<...>>)` — because if the concept were not satisfied the
recording hook would never fire and every downstream assertion would pass on an empty store. **A gate
that cannot distinguish "correct" from "absent" is not a gate.** Look for the version of each gate
that passes when nothing happened.

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
5. `docs/phase-1-review.md` — what the merged tree gets wrong or leaves owed.
6. `docs/reports/00`–`04`, `07`. **Read them twice: once for the design, and again at review time
   against the code.** Report 01 §3 names the carried boundary density that sank three attempts at
   the trajectory store; it was read at session start, and its relevance only became visible when a
   measurement demanded an explanation. A report read once is orientation; a report read against a
   diff is a review tool.

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

- **Identify the tree by SHA, and check whether the evidence already covers it, before building
  anything.** A commit whose parent is the branch tip you were going to apply it to *is* that tree
  plus that commit, so the gate output recorded against its SHA is this tree's gate output. Phase 1
  re-ran a build and two lifetime runs to reproduce numbers `implementation-notes.md` already
  attributed to the exact commit being moved. The recorded number and the SHA travel together for
  precisely this reason — so read the record first and re-measure only what it does not cover.
- **Write the change in full, review it, and build once at the end as verification.** Not a build
  per commit and not a gate per step: a rebuild is the most expensive instrument available and it
  answers a question that static reading usually answers better (§3).
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

Owed, all recorded with evidence in `implementation-notes.md` and `phase-1-review.md`, none blocking:

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
- **`ARCHITECTURE.md`** is still silent on this phase, and the hermite still lacks the pair of query
  readings §2.8 asks for.
