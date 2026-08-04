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

### Six rules for writing a claim into a packet

Each of these was learnt from a packet or a dry run that followed a specification
faithfully and produced the wrong thing. They are cheap to apply and they are where the
orchestrator's errors actually live.

1. **Name the object, not the operation.** "The seed writes `live.trait_adjoint`" is
   checkable, and it was false. "The seed leaves the term in the accumulator" is neither
   checkable nor false, so it survived unexamined and a packet was told to break working code.
2. **When you assert a defect, state the symptom it produces in a number.** A claimed bug
   with no stated signature cannot be tested against the code, and it will be taken on trust.
3. **Argue a control from every path that reaches the quantity, not from the equation you
   are thinking about.** A trait absent from the algebra still reaches the answer if the
   recording rebuilds anything.
4. **When you cite a symbol as available, check it is reachable from a landed branch.**
   "Designed", "built" and "landed" are three states, and a reader takes all three as
   available.
5. **When a gate asserts that state is unchanged, check the code restores by assignment and
   not by arithmetic.** A restore-by-arithmetic is a silent one-way ratchet, and it is
   invisible at the round values a hand-built harness picks.
6. **A comment is never evidence of behaviour.** A comment describing a hazard usually sits
   directly above the guard that removes it. This project has recorded such a comment as a
   live defect four times, and twice it reached the plan of record as a measurement.

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

**A documentation packet needs isolation too, and this is easy to get wrong.** An
agent editing only Markdown looks like it cannot collide with anything, so it is
tempting to point it at the main checkout. Do not. It still runs `git` there, and a
`git reset` or a `git stash` in the shared checkout moves the branch under whoever else
is working in it — including you. Measured: a prose-only sweep ran `git reset --mixed`
to restore its own uncommitted state and silently reverted a commit that had already
been pushed. **The rule is about the checkout, not about the file type.** Give every
packet a worktree and its own scratch subdirectory, and say which subdirectory in the
packet, or two agents will write `notes.txt` over each other.

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
- **Ask whether the gate can pass at all, and whether only the broken implementation can
  pass it.** Both have happened here. A gate that compares a new result against the old
  result for a quantity the old code got wrong *requires* the defect to be reproduced.
- **A bitwise gate is not automatically the strict one.** Re-associating a sum, adding terms
  that are exactly zero, or removing a multiplication by zero all move bits without changing
  the mathematics — and `0.0 * NaN` becoming `0.0` changes the mathematics without failing a
  test that uses `==`.

**This economy inverts when the phase moves numbers.** Then a step whose own claim is
bit-identity has earned its run, because it is the only thing separating "I broke the
loop" from "the value moved by the predicted amount" — attributing a large move to
one change requires that everything around it was proven inert. Most of
`NEXTSTEPS.md` is such a phase. What gets batched there is the **updating of the
reference numbers**, not the intermediate gates.

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
- **Change no reference number until the owner accepts the shift.** Recording it is
  the job; accepting it is theirs. Leave a moved assertion *failing* through the work
  and put the reference updates in as one pass at the end.

**Three kinds of failing assertion come out of a value-moving change and only one is
a reference update.** Conflating the first two ships a segfault or silently drops a
capability.

| | what it is | what it takes |
|---|---|---|
| a moved baseline | the same assertion, a shifted number | update the reference, with the shift recorded |
| a subject that stopped existing | the assertion can no longer express what it tested | **migrate the test**, and check first whether a capability went with it |
| a design choice | two readings, and the assertion encodes one | leave failing, record both, the owner's |

---

## 8. What the design asks of a model author

Every one of reports 01, 02, 03 and 04 closes with a section called "what this asks of a Strategy
author". Those four lists overlap heavily, they are the best engineering in the corpus, and until
now they lived only in reports whose headline subject is something else. **They are collected here
because they are the standing rules, not findings** — and because most of the defects this project
keeps finding are a rule below being broken somewhere nobody looked.

The engine cannot check most of them. That is the point: each is held by discipline, and each is
paired with the construct that motivated it, so a reviewer can look for the pattern rather than
the instance.

**On purity, because the reverse pass re-runs one cohort in isolation**

1. **Per-cohort state belongs in `Internals`, and nothing may carry between cohorts.** Anything
   the forward pass leaves on the shared `Strategy` and reads back is invisible to a sweep that
   re-runs one cohort alone. *`Leaf::soil_consumption_` carried the previous cohort's deep-layer
   uptake on 33.78 percent of production records, because `resize` does not fill existing
   elements.*
2. **The safe pattern for a shared mutable member is write-before-read, and it is not enforced.**
   A member read before being written in the same call is a cross-cohort channel, and **no test
   would catch it**: the forward pass is order-deterministic, so a stale read reproduces exactly.
   *`mass_root_prop_` is safe because it is `.assign`ed at the top of every call; the `Leaf` is
   safe only because `set_physiology` re-seats it.*
3. **A cache must be keyed on everything its value depends on, or not exist.** *`photo_temp_cached_`
   caches `vcmax_` on a key omitting `vcmax_25` — correct only while that parameter is run-constant,
   and a differentiation target is exactly a parameter someone intends to vary.*
4. **Every early exit sets an operating point — set all of it.** An exit that writes a partial state
   is a cross-cohort channel. *`set_shutdown_state` set three members and left a fourth stale.*

**On inner solves, because a search is not a function**

5. **Return the solution, expose the residual, never expose the search.** For an implicitly defined
   quantity the differentiable object is the defining equation. *`golden_section_max`'s argmax is an
   exact affine function of its bracket and independent of the objective's values, so taping the
   search yields the derivative of the bracket.*
6. **An objective at its own optimum is free; its other consumers are not.** Ask of every output
   whether it *is* the objective or merely reads the argument that maximised it. *The envelope
   theorem covers `profit_` completely and `soil_consumption_` not at all; the measured cost of
   conflating them is 4 to 12 percent.*
7. **A feasibility bound is part of the model, so its derivative is part of the answer** — and that
   branch is *exact and cheaper* than the interior one, which is the opposite of what one expects.
8. **A search's stopping tolerance is not the accuracy of a derivative built on its answer.** An
   argmax consumed by anything but the objective must be polished to a stationary point before it
   is used as a linearisation point. *Unpolished at `GSS_tol_abs = 1e-3` the error is 3.5 percent;
   polished it is 4.5e-10 at every tolerance, and tightening the search instead plateaus at 6e-6.*
9. **A guard that returns NaN and falls back to a finite difference is a severance in disguise** —
   invisible in the value, wrong in the derivative.

**On aggregation, because the domain moves**

10. **If you integrate over your own size, you need the integrand's slope.** Easy to miss because
    the value is correct and only the derivative is wrong. *Applies to any aggregation with a
    state-dependent domain — a crown, and equally TF24's root mass over soil layers with
    `rooting_depth = min(height, 1.5)`.*
11. **If you declare a cumulative form, declare its density too — and check they agree.** *`q` is
    exactly `-dQ/dz`, which is what makes the slope reduction free; nothing currently ties them, so
    they could drift apart silently.*
12. **Value and slope must come from one construct.** Two constructs agree nowhere except by
    accident and the disagreement is invisible in the value.
13. **Know where your field is non-smooth, and put knots there** — or accept the rate you get. *`A(z)`
    is C1 and not C2, with a curvature break at every cohort top, and a refiner chasing value error
    clusters near the breaks rather than landing on them.*
14. **Narrow the environment interface.** The cost of differentiating a cohort scales with how many
    environment values it reads. *A Strategy querying the environment at state-dependent points
    chosen by a search would be materially more expensive.*
15. **A reduction over the size distribution begins at the inflow boundary, not at the smallest
    cohort.** *The light reduction integrates from `height_0` and the water reduction from the
    smallest cohort, so recruits between the two transpire without being billed; and
    `consumption_rate` returns exactly zero for `size() < 2`, so the water channel switches on
    discontinuously at the second cohort.*

**On what carries a derivative**

16. **Positions are structure; values carry derivatives.** Knot positions, quadrature abscissae and
    cohort orderings are decided on passive values and are `double` by type. **Letting a knot *count*
    depend on an active value makes the recorded computation state-dependent.**
17. **Fixed quadrature rules are structure; adaptive ones are not.** *`quadrature::QK` places nodes
    as a deterministic affine function of its bounds, so an active bound tapes correctly.*
18. **Never define a rate as a numerical derivative of an active quantity.** The stencil may be a
    legitimate discretisation — often it is the upwind form and the analytic alternative is
    unstable — but evaluated in `double` on a differentiated path it **silently drops the channel it
    discretises**.
19. **Difference on a grid the model already has, not on one you invent.** In a
    method-of-characteristics scheme the cohorts *are* the grid and their spacing has an exact rate.
    A probe distance is a tolerance chosen for roundoff, and dividing by it amplifies roundoff by
    its reciprocal whether or not the differenced quantity is smooth.
20. **If you difference something, know its smoothness at your step size.** *A probe distance of
    1e-6 against a quantity moving in steps of 1e-3 is safe only because the steps are locally flat,
    and nothing records that dependency.*
21. **Anything defined as a small difference of large quantities must be computed as itself.** *The
    uptake's response to uniform drying is about one percent of what the potentials do, and a
    whole-solve finite difference resolves the collar to four digits — so it cannot measure the
    residue it would be verifying.*

**On kinks and switches**

22. **Say whether a switch is a kink you mean.** A zero derivative may be exactly the biology. The
    point is that it should be a recorded decision rather than an artefact of writing an `if`.
23. **A clamp is a derivative severance; say whether you mean it.** *Sometimes it is the model;
    sometimes it papers over an interpolant that undershoots, which is a different problem with a
    different fix.*
24. **A declared smoothing scale must be sized against the spread of its argument.** Much smaller
    and it is a hard switch wearing a smooth coat — and then its derivative is a **spike**, which for
    a gradient is worse than the switch was. *`storage_prod_eps = 1e-4` is the one place in this
    model where a mollification was sized against data: 3.6 percent of records sit within one scale
    length and 29 percent within ten.*
25. **Count your branches before designing around them, and say which driver you counted on.** *Five
    exits were documented as four, the sixth case was not documented at all, and it was the only one
    that appeared. All six then measured zero on the default driver — and that zero is a property of
    the driver, not of the model.* A counter behind an environment variable is cheap and it is the
    difference between designing for the model and designing for a worry.

**One meta-rule, which is this project's own experience.** Rules 1 to 3 could plausibly be made
structural rather than conventional, and doing so would convert the riskiest of them from discipline
into compile-time or assertion-time facts. That is the highest-value engineering item in the corpus
that nobody has scheduled.

---

## 9. Where the state lives

| what | where |
|---|---|
| what to build, in order, with its gates | `NEXTSTEPS.md` |
| how to verify, build, measure; the reference numbers; the harnesses | `METHOD.md` |
| the derivations the plan rests on | `docs/reports/00`–`04` |
| the derivatives, and the symbol that carries each quantity | `docs/reports/05` |
| what the derivatives mean ecologically, and what a defect costs | `docs/reports/06` |
| where the system is narrower than it looks | `docs/reports/07` |
| what the machinery could answer beyond the trait gradient | `docs/reports/08` |
| re-runnable probes and spike patches | `docs/probes/` |
| what was built, at which commit, and what each number moved | `docs/archive/implementation-notes.md` |
| the plan the build was run against | `docs/archive/build-plan.md` |

The last two are **archived**: every task in that plan is built, and the ledger's job
was to be the one home for numbers nobody is now re-deriving. Read them for
archaeology, cite them by commit and path, and do not design from them.

---

## 10. Dry-run every wave before you commission it

**A dry run is one packet per task in the wave, told to write the code and throw it
away.** Its deliverable is not the diff. Its deliverable is a list of the places the
specification was wrong.

**Why this is a standing step and not a one-off.** A dry run over four task
specifications found a defect in **four of four**, and none of the four was the kind of
thing a careful reading finds:

| what the specification said | what the code said |
|---|---|
| use `odelia::incomplete_gamma` | the function is on an abandoned branch and exists in neither repository |
| the leaf state after one call matches the state after `1 + n` calls | one member restores by accumulating arithmetic, so it does not return to its value |
| `clear_trait_adjoint()` runs after the seed and removes the term | it runs on a different object; moving it would have summed three functionals into one row |
| `k_I` does not reach the census, so use it as the control | the recording rebuilds the boundary node, so parameters the metric algebra never names reach the census |
| the transport derivative is differenced across a grid whose knot count moves | the grid is captured before any perturbation and held; the figure quoted was the comment justifying the capture |

Each of these would have cost a packet its whole cycle, and two of them would have
produced a plausible wrong answer rather than a failure. **The cheapest way to find them
was to try to write the code.**

### What to put in a dry-run packet

The ordinary packet fields of section 2, plus:

1. **Say it is a dry run and that nothing lands.** Own worktree, no commit, no push.
2. **Name the claims in the specification you most doubt**, and ask for each to be
   checked against the code before it is relied on. Be specific: "verify that only these
   five quantities depend on the seed, and name anything else you find."
3. **Ask where the specification forced a choice it did not authorise.** This is the
   field that produced the most value. Instruct it to report both readings and implement
   neither.
4. **Bound the builds.** One or two. A dry run's value is in the reading, not the running.
5. **Ask what the gate cannot see**, and whether the gate as written can pass at all.

### What to do with the result

Fix the plan, then commission the wave. **Do not hand a corrected specification to the
same agent as a continuation** — resume it only if the correction is small; otherwise the
dry run has changed what the task is, and the task should be re-scoped.

A dry run that finds nothing is evidence the wave is ready. That has not happened yet.

**Give a dry run the standing to overturn its own brief, and mean it.** The instruction that
produced the most value was to report both readings and implement neither. The one that
produced the most *correction* was to check every claim in the brief against the code before
relying on it — a mechanical pass over every named symbol has found more, and more severe,
defects than careful reasoning about the design has.
