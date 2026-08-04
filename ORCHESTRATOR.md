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

**The evidence for where the risk sits.** Across four phases, subagents corrected
the architect **twenty-three times** and stopped on real contradictions rather than
papering over them. Every expensive failure was the orchestrator's: an unguarded
edit, an unread document, an unpriced gate, an unverified environment. So the
discipline below applies hardest to your own hands.

**The organising fact.** Every costly failure traced back to a cheap check that was
skipped. Reading one section — five minutes — saved three attempts at one task.
Confirming two repositories compile together — thirty seconds — saved three dead
first cycles. **Slow is smooth and smooth is fast.**

---

## 1. Before you send anything

Six checks, none longer than a few minutes. Each one, skipped, cost real time.

1. **Read the section that owns the thing, not the section that mentions it.** Two
   sections of the design disagreed about whether a trajectory record carries the
   step size; two packets written from the wrong one both failed. **When two
   documents disagree, that is the finding and it outranks the task.**
2. **Never cite a document in a packet you have not read.** Packets have been
   pointed at sections by line number by someone who had read neither, and the
   agents were then better informed than the person directing them.
3. **Prove the packet's environment compiles.** A plant base paired with the wrong
   odelia bit three times — 56, 68 and an unbuildable pairing. Build it yourself, or
   state which incompatibility the packet will hit and why that is acceptable. **A
   packet's environment is part of its specification.**
4. **Cost every gate, and write the cost in the packet.** One gate ran an hour and
   was retracted; a cheaper configuration exercised the same defect *better*.
5. **Check the gate is satisfiable.** One packet was told an active value must equal
   a `double` value to the last bit, which this project had already measured to be
   impossible. **Ask what would make the gate impossible, not just what would make
   it fail.**
6. **Run the gate on the unmodified tree and confirm it prints a number you
   recognise.** `METHOD.md` §1 is the whole of this rule and it is the one that
   caught five unfailable gates.

**And do not tell an agent which obstruction will be largest unless you have
measured it.** A guess stated as an expectation is a bias the agent spends evidence
to overturn. One packet was told to expect the untemplated environment; the largest
group was `std::`-qualified math, which has nothing to do with it.

---

## 2. The packet

A packet is a bounded change whose gate someone who was not there can re-run. If
the gate cannot be written as a command with an expected answer, the packet is not
ready. Every field, every time:

1. **The change in one sentence, plus an explicit file allowlist.** Touching
   anything else is a deviation to report, not initiative.
2. **The gate as a command, its expected answer, and its cost.**
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
9. **Its own baseline first** — take the base tree's reference number in the
   packet's own worktree before the first edit, and stop if it does not reproduce.
10. **Report format:** the diff, each gate's output pasted verbatim, and an explicit
    "what I could not do". Say plainly: *do not report a gate as passing that you
    did not run.*

**A baseline is a property of a commit, a configuration and the script that
produced it.** Quote all three. Suite counts were handed to packets from the wrong
tip three times, and one model's configuration was handed to all three models once.

---

## 3. Isolation

Each packet gets its own worktree, its own R library when it touches `odelia`, and
its own scratch directory. plant reaches odelia through the *installed* package, so
two agents installing into one library overwrite each other's headers.

```sh
mkdir -p /home/user/lib-<packet>
export R_LIBS_USER=/home/user/lib-<packet>
Rscript -e 'install.packages("<odelia worktree>", repos = NULL, type = "source")'
```

**Your own verification needs its own worktree too** — a detached checkout at the
commit SHA that nothing else touches. Two concurrent builds in one worktree leave a
half-written `.so`, and **loading one succeeds and returns plausible wrong
numbers**. See `METHOD.md` §4.

---

## 4. Sequence, fan-out and cost

**Fan out the writing; take the builds one at a time in dependency order.** These
are separable. Authoring costs context, not CPU. Building and running are the
contended resources, and a production run goes from about 90 s idle to about 7
minutes under a wave — so three concurrent build lanes make every gate in every
lane five times slower, and a wave *loses* to a queue whenever the lanes are not
genuinely independent.

**Fanning out a dependency chain thrashes**: the downstream agent rebases onto a
moving base and its bit-identity gate measures the rebase.

**Count the builds before starting.** A phase's wall clock is roughly its build
count times one build. A clean build is about 95 s here and up to ten minutes on a
loaded box, so the way to fit a phase in one turn is to reduce the count rather
than to overlap it.

**Contention is self-inflicted — do not read your own scheduling as an environment
limit.** With one packet running, a single process gets 99.9 percent of a core.

**Elapsed time is not progress.** A packet ran seven hours, produced one merge
commit and died with its container. **Absence of a completion notification is
indistinguishable from work**: check file mtimes and CPU time against elapsed, and
give a multi-hour packet checkpoints so a reclaim leaves something behind.

**An expensive gate makes an agent unreachable.** A queued correction lands only at
the agent's next tool round. Bound the cost when writing the packet; failing that,
kill by PID, which returns the call and delivers the message.

---

## 5. Gate what the gate can see

**Six bit-identity gates on a type-level refactor found nothing, and a grep found
three real defects.** Templating at `S = double` generates identical object code, so
a value gate there is blind to a deduced return type, a swapped like-typed argument
or a missing guard. So:

- **Write the change in full, review it statically and adversarially, then build
  once.** Keep commits as a structure for reading, not as a schedule of gates.
- **Put the real check where the errors surface.** For scalar templating that is the
  active build, not the `double` suite.
- **Prove a gate command fails when it should.** Break the thing it checks and
  confirm the command notices.

**This economy inverts when the phase moves numbers.** Then a step whose own claim
is bit-identity has earned its run, because it is the only thing separating "I broke
the loop" from "the value moved by the predicted amount". One restructure being
bit-identical is the whole reason a 10.3x move could be attributed to one stencil.
In a value-moving phase what gets batched is the **re-blessing**, not the
intermediate gates.

---

## 6. Stopping is the product

Five packets stopped without finishing and every one was right to; two falsified
statements in the plan. **A stopped packet with a diagnosis is worth more than a
finished one that papered over a contradiction** — and the practice only works if
that is true in fact and not just in the packet's wording.

- **Say so when the packet was wrong.** An agent told "your environment was broken
  and it was mine" reports the next problem faster.
- **Ask for the cost.** "Which of my gates were uneconomic" is how the
  90 s-versus-7 minutes fact surfaced.
- **Prefer a resume to a fresh packet.** An agent resumed with its context intact
  fixed a defect in one round.
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
  overriding it.** Five times the agent was right and the plan or the packet was
  wrong.
- **Distinguish an agent's harness from its tree.** Comparisons taken with one
  harness on both sides are sound; the absolute numbers may not be.
- **A mechanical sweep over every diff before it lands** —
  `scripts/build/style-sweep.sh <worktree> <base>` — **plus reading every comment
  line you did not write.** The sweep reports candidates, not verdicts, and it cannot
  see a comment the change made false.
- **The cross-model tripwire on every merge, not at phase end.** `METHOD.md` §5.
- **One integration branch per repository.** After each merge, verify every change
  is present by **reading the merged tree** rather than trusting the auto-merge, and
  check the arithmetic: if four packets added 4, 11, 27 and 7 assertions to a
  264-pass baseline, the merged tree shows 313, and anything else means the merge
  lost or duplicated something.
- **Some work has no packet and it is the integrator's.** Before closing, list the
  documents the change touches and check each against what landed. This has been
  missed once, on `odelia/AUTODIFF.md`.
- **Re-bless nothing until the owner accepts the shift.** Recording it is the job;
  accepting it is theirs. Leave a moved assertion *failing* through the work and put
  the re-blessing in as one pass at the end.

**Three kinds of failing assertion come out of a value-moving change and only one is
a re-blessing.** Conflating two of them shipped a segfault and a lost R capability.

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
| what was built, at which commit, and what each number moved | `docs/archive/implementation-notes.md` |
| the plan the build was run against | `docs/archive/build-plan.md` |

The last two are **archived**: every task in the plan is built, and the ledger's job
was to be the one home for a number nobody is now re-deriving. Read them for
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
